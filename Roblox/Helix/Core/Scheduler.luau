
----------------------------------------------------------------
-- FILE: Scheduler
----------------------------------------------------------------

local HelixConfig = require(script.Parent.HelixConfig)
local Clock = require(script.Parent.Clock)
local Registry = require(script.Parent.Registry)

local Scheduler = {}

local accumulator = 0
local fixedStep = 1 / HelixConfig.TickRate

function Scheduler:Update(deltaTime)
    accumulator += deltaTime
    local ticksProcessed = 0

    while accumulator >= fixedStep and ticksProcessed < HelixConfig.MaxTicksPerFrame do
        self:RunTick()
        accumulator -= fixedStep
        ticksProcessed += 1
    end
end

function Scheduler:RunTick()
    for _, data in ipairs(Registry:GetOrdered()) do
        if data.instance.Tick then
            data.instance:Tick()
        end
    end
    Clock:Increment()
end

return Scheduler
