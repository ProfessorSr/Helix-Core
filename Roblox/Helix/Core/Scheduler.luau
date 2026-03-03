----------------------------------------------------------------
-- FILE: Scheduler
----------------------------------------------------------------

local Registry = require(script.Parent.Registry)
local TimeAuthority = require(script.Parent.Authorities.TimeAuthority)
local EventAuthority = require(script.Parent.Authorities.EventAuthority)
local GameplayAuthority = require(script.Parent.Authorities.GameplayAuthority)
local ProfilerAuthority = require(script.Parent.Authorities.ProfilerAuthority)
local HelixConfig = require(script.Parent.HelixConfig)


local Scheduler = {}

-- Boot-locked configuration
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
local profilingEnabled = true

local function ensureAuthoritiesInitialized()
    if authoritiesReady then
        return
    end

    local configuredMaxTicks = HelixConfig:Get("MaxTicksPerFrame")
    if type(configuredMaxTicks) == "number" then
        maxTicksPerFrame = math.max(1, math.floor(configuredMaxTicks))
    end

    local configuredSeed = HelixConfig:GetSeed()
    if type(configuredSeed) == "number" then
        seed = configuredSeed
        resetRng(seed)
    end

    local fixedStep = HelixConfig:GetFixedStep()
    if fixedStep <= 0 then
        error("[Scheduler] Invalid fixed step from config.")
    end

    local configuredProfiling = HelixConfig:Get("ProfilingEnabled")
    if type(configuredProfiling) == "boolean" then
        profilingEnabled = configuredProfiling
    end

    TimeAuthority:Initialize(fixedStep)
    TimeAuthority:Lock()

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
    if fixedStep <= 0 then
        return
    end

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
    local fixedStep = TimeAuthority:GetFixedStep()
    if fixedStep <= 0 then
        return
    end

    TimeAuthority:Advance()
    local tickIndex = TimeAuthority:GetTickIndex()
    if profilingEnabled then
        ProfilerAuthority:BeginFrame(tickIndex)
    end

    if profilingEnabled then
        ProfilerAuthority:BeginSection("EventAuthority")
    end
    EventAuthority:ProcessTick(tickIndex)
    if profilingEnabled then
        ProfilerAuthority:EndSection("EventAuthority")
    end

    if profilingEnabled then
        ProfilerAuthority:BeginSection("GameplayAuthority")
    end
    GameplayAuthority:ProcessTick(tickIndex, fixedStep)
    if profilingEnabled then
        ProfilerAuthority:EndSection("GameplayAuthority")
    end

    for _, data in ipairs(Registry:GetOrdered()) do
        if data.instance.Tick then
            local sectionName = "Subsystem:" .. tostring(data.name)
            if profilingEnabled then
                ProfilerAuthority:BeginSection(sectionName)
            end
            data.instance:Tick(fixedStep)
            if profilingEnabled then
                ProfilerAuthority:EndSection(sectionName)
            end
        end
    end

    if profilingEnabled then
        ProfilerAuthority:EndFrame()
    end
end


function Scheduler:SetConfig(config)
    if configLocked then
        error("Scheduler config is locked after boot.")
    end

    if type(config.TickRate) == "number" and HelixConfig.Set then
        HelixConfig:Set("TickRate", config.TickRate)
    end

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

function Scheduler:Reset()
    accumulator = 0
    timeScale = 1
    authoritiesReady = false
    profilingEnabled = true
    local configuredSeed = HelixConfig:GetSeed()
    if type(configuredSeed) == "number" then
        seed = configuredSeed
    end
    resetRng(seed)
end

return Scheduler
