----------------------------------------------------------------
-- FILE: RobloxHost
----------------------------------------------------------------

local Scheduler = require(script.Parent.Parent.Parent.Core.Scheduler)
local Registry = require(script.Parent.Parent.Parent.Core.Registry)
local Boot = require(script.Parent.Parent.Parent.Core.Boot)
local HelixConfig = require(script.Parent.Parent.Parent.Core.HelixConfig)


local TimeSubsystem = require(script.Parent.Parent.Subsystems.Time.TimeSubsystem)
local PhysicsSubsystem = require(script.Parent.Parent.Subsystems.Physics.PhysicsSubsystem)
local VehicleSubsystem = require(script.Parent.Parent.Subsystems.Vehicle.VehicleSubsystem)
local CharacterSubsystem = require(script.Parent.Parent.Subsystems.Character.CharacterSubsystem)
local CameraSubsystem = require(script.Parent.Parent.Subsystems.Camera.CameraSubsystem)
local AnimationSubsystem = require(script.Parent.Parent.Subsystems.Animation.AnimationSubsystem)
local AISubsystem = require(script.Parent.Parent.Subsystems.AI.AISubsystem)
local ClimateSubsystem = require(script.Parent.Parent.Subsystems.Climate.ClimateSubsystem)
local AudioSubsystem = require(script.Parent.Parent.Subsystems.Audio.AudioSubsystem)
local LightingSubsystem = require(script.Parent.Parent.Subsystems.Lighting.LightingSubsystem)
local NetworkingSubsystem = require(script.Parent.Parent.Subsystems.Networking.NetworkingSubsystem)
local ReplicationSubsystem = require(script.Parent.Parent.Subsystems.Replication.ReplicationSubsystem)
local SaveLoadSubsystem = require(script.Parent.Parent.Subsystems.SaveLoad.SaveLoadSubsystem)
local EconomySubsystem = require(script.Parent.Parent.Subsystems.Economy.EconomySubsystem)

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

    -- Initialize subsystems (Unreal parity)
    Registry:Register("Time", TimeSubsystem, 10)
    Registry:Register("Physics", PhysicsSubsystem, 20)
    Registry:Register("Vehicle", VehicleSubsystem, 30)
    Registry:Register("Character", CharacterSubsystem, 40)
    Registry:Register("Camera", CameraSubsystem, 50)
    Registry:Register("Animation", AnimationSubsystem, 60)
    Registry:Register("AI", AISubsystem, 70)
    Registry:Register("Climate", ClimateSubsystem, 80)
    Registry:Register("Audio", AudioSubsystem, 90)
    Registry:Register("Lighting", LightingSubsystem, 100)
    Registry:Register("Networking", NetworkingSubsystem, 110)
    Registry:Register("Replication", ReplicationSubsystem, 120)
    Registry:Register("SaveLoad", SaveLoadSubsystem, 130)
    Registry:Register("Economy", EconomySubsystem, 140)

    TimeSubsystem:Initialize()
    PhysicsSubsystem:Initialize()
    VehicleSubsystem:Initialize()
    CharacterSubsystem:Initialize()
    CameraSubsystem:Initialize()
    AnimationSubsystem:Initialize()
    AISubsystem:Initialize()
    ClimateSubsystem:Initialize()
    AudioSubsystem:Initialize()
    LightingSubsystem:Initialize()
    NetworkingSubsystem:Initialize()
    ReplicationSubsystem:Initialize()
    SaveLoadSubsystem:Initialize()
    EconomySubsystem:Initialize()
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

function RobloxHost:Shutdown()
    TimeSubsystem:Shutdown()
    PhysicsSubsystem:Shutdown()
    VehicleSubsystem:Shutdown()
    CharacterSubsystem:Shutdown()
    CameraSubsystem:Shutdown()
    AnimationSubsystem:Shutdown()
    AISubsystem:Shutdown()
    ClimateSubsystem:Shutdown()
    AudioSubsystem:Shutdown()
    LightingSubsystem:Shutdown()
    NetworkingSubsystem:Shutdown()
    ReplicationSubsystem:Shutdown()
    SaveLoadSubsystem:Shutdown()
    EconomySubsystem:Shutdown()
end

return RobloxHost
