----------------------------------------------------------------
-- FILE: Scheduler
----------------------------------------------------------------

local Registry = require(script.Parent.Registry)
local TimeAuthority = require(script.Parent.Authorities.TimeAuthority)


local Scheduler = {}

-- Boot-locked configuration
local tickRate = 60
local maxTicksPerFrame = 5
local seed = 0

local configLocked = false

-- Deterministic RNG (mirrors Unreal)
local rng = Random.new(seed)

local accumulator = 0
local timeScale = 1

function Scheduler:GetRandom()
    return rng:NextNumber()
end

function Scheduler:Update(deltaTime)
    local scaledDelta = deltaTime * timeScale
    accumulator += scaledDelta

    local fixedStep = 1 / tickRate

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
    TimeAuthority:Advance()

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

    rng = Random.new(seed)
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
