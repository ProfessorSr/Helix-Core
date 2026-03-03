----------------------------------------------------------------
-- FILE: Scheduler
----------------------------------------------------------------

local Registry = require(script.Parent.Registry)
local TimeAuthority = require(script.Parent.Authorities.TimeAuthority)
local EventAuthority = require(script.Parent.Authorities.EventAuthority)
local HelixConfig = require(script.Parent.HelixConfig)


local Scheduler = {}

-- Boot-locked configuration
local tickRate = 60
local maxTicksPerFrame = 5
local seed = 0

local configLocked = false

-- Deterministic RNG state (LCG).
local rngState = seed

local function resetRng(newSeed)
    rngState = newSeed % 2147483647
    if rngState <= 0 then
        rngState = 1
    end
end

local function nextRandom()
    rngState = (rngState * 16807) % 2147483647
    return (rngState - 1) / 2147483646
end

resetRng(seed)

local accumulator = 0
local timeScale = 1
local authoritiesReady = false

local function ensureAuthoritiesInitialized()
    if authoritiesReady then
        return
    end

    local fixedStep = HelixConfig:GetFixedStep()
    TimeAuthority:Initialize(fixedStep)
    TimeAuthority:Lock()

    if fixedStep > 0 then
        tickRate = 1 / fixedStep
    end

    authoritiesReady = true
end

function Scheduler:GetRandom()
    return nextRandom()
end

function Scheduler:Start()
    ensureAuthoritiesInitialized()
    accumulator = 0
end

function Scheduler:Update(deltaTime)
    ensureAuthoritiesInitialized()

    local scaledDelta = deltaTime * timeScale
    accumulator += scaledDelta

    local fixedStep = TimeAuthority:GetFixedStep()

    local ticksProcessed = 0

    while accumulator >= fixedStep and ticksProcessed < maxTicksPerFrame do
        self:RunTick()
        accumulator -= fixedStep
        ticksProcessed += 1
    end

    if ticksProcessed == maxTicksPerFrame and accumulator >= fixedStep then
        accumulator = 0
    end
end

function Scheduler:RunTick()
    ensureAuthoritiesInitialized()

    TimeAuthority:Advance()
    EventAuthority:ProcessTick(TimeAuthority:GetTickIndex())

    for _, data in ipairs(Registry:GetOrdered()) do
        if data.instance.Tick then
            data.instance:Tick()
        end
    end
end


function Scheduler:SetConfig(config)
    if configLocked then
        error("Scheduler config is locked after boot.")
    end

    tickRate = config.TickRate or tickRate
    maxTicksPerFrame = config.MaxTicksPerFrame or maxTicksPerFrame
    seed = config.Seed or seed

    resetRng(seed)
end

function Scheduler:LockConfig()
    configLocked = true
end

function Scheduler:SetTimeScale(value)
    timeScale = value
end

function Scheduler:GetTimeScale()
    return timeScale
end

return Scheduler
