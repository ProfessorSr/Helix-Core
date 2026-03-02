
----------------------------------------------------------------
-- FILE: RobloxHost
----------------------------------------------------------------

local Scheduler = require(script.Parent.Parent.Parent.Core.Scheduler)
local Registry = require(script.Parent.Parent.Parent.Core.Registry)
local Boot = require(script.Parent.Parent.Parent.Core.Boot)

local TestSubsystem = require(script.Parent.Parent.Subsystems.TestSubsystem)

local RobloxHost = {}

function RobloxHost:Start()

    -- Register subsystems BEFORE boot lock
    Registry:Register("TestSubsystem", TestSubsystem, 10)

    -- Lock registry
    Boot:Initialize()

    local RunService = game:GetService("RunService")
    local last = tick()

    RunService.Heartbeat:Connect(function()
        local now = tick()
        local delta = now - last
        last = now
        Scheduler:Update(delta)
    end)
end

return RobloxHost
