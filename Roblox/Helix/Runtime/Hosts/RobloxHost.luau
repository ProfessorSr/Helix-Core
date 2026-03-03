----------------------------------------------------------------
-- FILE: RobloxHost
----------------------------------------------------------------

local Scheduler = require(script.Parent.Parent.Parent.Core.Scheduler)
local Registry = require(script.Parent.Parent.Parent.Core.Registry)
local Boot = require(script.Parent.Parent.Parent.Core.Boot)
local HelixConfig = require(script.Parent.Parent.Parent.Core.HelixConfig)

local TestSubsystem = require(script.Parent.Parent.Subsystems.TestSubsystem)

local RobloxHost = {}

function RobloxHost:Start()

    -- =========================================================
    -- Host Capability Declaration (Roblox)
    -- =========================================================

    Boot:SetHostCapabilities({
        ["Time.FixedStep"] = true,
        ["Lifecycle.Boot"] = true,
        ["Lifecycle.LockRegistry"] = true,
        ["Scheduler.Update"] = true,
    })

    Boot:RegisterRequiredCapability("Time.FixedStep")
    Boot:RegisterRequiredCapability("Lifecycle.Boot")
    Boot:RegisterRequiredCapability("Lifecycle.LockRegistry")
    Boot:RegisterRequiredCapability("Scheduler.Update")

    -- =========================================================
    -- Subsystem Registration
    -- =========================================================

    Registry:Register("TestSubsystem", TestSubsystem, 10)

    -- =========================================================
    -- Boot (validates capabilities + locks registry)
    -- =========================================================

    Boot:Initialize()

    -- =========================================================
    -- Runtime Loop + Diagnostics
    -- =========================================================

    local RunService = game:GetService("RunService")

    local last = tick()
    local elapsed = 0
    local fixedStepCount = 0
    local accumulator = 0
    local fixedStep = 1 / HelixConfig:Get("TickRate")

    RunService.Heartbeat:Connect(function()
        local now = tick()
        local delta = now - last
        last = now

        -- Forward into Helix Scheduler
        Scheduler:Update(delta)

        -- Host diagnostics (mirrors Unreal)
        elapsed += delta
        accumulator += delta

        while accumulator >= fixedStep do
            fixedStepCount += 1
            accumulator -= fixedStep
        end

        if elapsed >= 1.0 then
            local hz = fixedStepCount / elapsed

            print(string.format(
                "[HelixHost] Phase=Running | FixedStepsLastSecond=%d | Hz=%.2f",
                fixedStepCount,
                hz
            ))

            fixedStepCount = 0
            elapsed = 0
        end
    end)
end

return RobloxHost
