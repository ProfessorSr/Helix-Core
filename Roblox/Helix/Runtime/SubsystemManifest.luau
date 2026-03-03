--[[
----------------------------------------------------------------
-- FILE: SubsystemManifest
-- TYPE: Explicit Runtime Manifest
-- LAST UPDATED (UTC): 2026-03-03T07:55:00Z
----------------------------------------------------------------
]]

local Subsystems = script.Parent:WaitForChild("Subsystems")
local Hosts = script.Parent:WaitForChild("Hosts")

local CoreSubsystems = Subsystems:WaitForChild("Core")
local EnterpriseSubsystems = Subsystems:WaitForChild("Enterprise")
local ExpansionSubsystems = Subsystems:WaitForChild("Expansion")
local SimulationSubsystems = Subsystems:WaitForChild("Simulation")

local CoreHosts = Hosts:WaitForChild("Core")
local EnterpriseHosts = Hosts:WaitForChild("Enterprise")
local ExpansionHosts = Hosts:WaitForChild("Expansion")
local SimulationHosts = Hosts:WaitForChild("Simulation")

local function entry(name, domain, phase, subsystemModule, readerModule, writerModule)
    return {
        Name = name,
        Domain = domain,
        Version = "1.0.0",
        Phase = phase,
        Module = subsystemModule,
        ReaderModule = readerModule,
        WriterModule = writerModule,
    }
end

return {
    entry("AnimationSubsystem", "Core", 1, CoreSubsystems:WaitForChild("AnimationSubsystem"), CoreHosts:WaitForChild("AnimationReader"), CoreHosts:WaitForChild("AnimationWriter")),
    entry("AudioSubsystem", "Core", 1, CoreSubsystems:WaitForChild("AudioSubsystem"), CoreHosts:WaitForChild("AudioReader"), CoreHosts:WaitForChild("AudioWriter")),
    entry("CameraSubsystem", "Core", 1, CoreSubsystems:WaitForChild("CameraSubsystem"), CoreHosts:WaitForChild("CameraReader"), CoreHosts:WaitForChild("CameraWriter")),
    entry("EventSubsystem", "Core", 1, CoreSubsystems:WaitForChild("EventSubsystem"), CoreHosts:WaitForChild("EventReader"), CoreHosts:WaitForChild("EventWriter")),
    entry("InputSubsystem", "Core", 1, CoreSubsystems:WaitForChild("InputSubsystem"), CoreHosts:WaitForChild("InputReader"), CoreHosts:WaitForChild("InputWriter")),
    entry("NetworkingSubsystem", "Core", 1, CoreSubsystems:WaitForChild("NetworkingSubsystem"), CoreHosts:WaitForChild("NetworkingReader"), CoreHosts:WaitForChild("NetworkingWriter")),
    entry("PhysicsSubsystem", "Core", 1, CoreSubsystems:WaitForChild("PhysicsSubsystem"), CoreHosts:WaitForChild("PhysicsReader"), CoreHosts:WaitForChild("PhysicsWriter")),
    entry("TimeSubsystem", "Core", 1, CoreSubsystems:WaitForChild("TimeSubsystem"), CoreHosts:WaitForChild("TimeReader"), CoreHosts:WaitForChild("TimeWriter")),
    entry("TransformSubsystem", "Core", 1, CoreSubsystems:WaitForChild("TransformSubsystem"), CoreHosts:WaitForChild("TransformReader"), CoreHosts:WaitForChild("TransformWriter")),
    entry("WorldSubsystem", "Core", 1, CoreSubsystems:WaitForChild("WorldSubsystem"), CoreHosts:WaitForChild("WorldReader"), CoreHosts:WaitForChild("WorldWriter")),

    entry("AccountSubsystem", "Enterprise", 2, EnterpriseSubsystems:WaitForChild("AccountSubsystem"), EnterpriseHosts:WaitForChild("AccountReader"), EnterpriseHosts:WaitForChild("AccountWriter")),
    entry("PersistenceSubsystem", "Enterprise", 2, EnterpriseSubsystems:WaitForChild("PersistenceSubsystem"), EnterpriseHosts:WaitForChild("PersistenceReader"), EnterpriseHosts:WaitForChild("PersistenceWriter")),
    entry("PolicySubsystem", "Enterprise", 2, EnterpriseSubsystems:WaitForChild("PolicySubsystem"), EnterpriseHosts:WaitForChild("PolicyReader"), EnterpriseHosts:WaitForChild("PolicyWriter")),
    entry("SecuritySubsystem", "Enterprise", 2, EnterpriseSubsystems:WaitForChild("SecuritySubsystem"), EnterpriseHosts:WaitForChild("SecurityReader"), EnterpriseHosts:WaitForChild("SecurityWriter")),
    entry("TelemetrySubsystem", "Enterprise", 2, EnterpriseSubsystems:WaitForChild("TelemetrySubsystem"), EnterpriseHosts:WaitForChild("TelemetryReader"), EnterpriseHosts:WaitForChild("TelemetryWriter")),

    entry("AssetSubsystem", "Expansion", 3, ExpansionSubsystems:WaitForChild("AssetSubsystem"), ExpansionHosts:WaitForChild("AssetReader"), ExpansionHosts:WaitForChild("AssetWriter")),
    entry("ComponentSubsystem", "Expansion", 3, ExpansionSubsystems:WaitForChild("ComponentSubsystem"), ExpansionHosts:WaitForChild("ComponentReader"), ExpansionHosts:WaitForChild("ComponentWriter")),
    entry("ReplicationSubsystem", "Expansion", 3, ExpansionSubsystems:WaitForChild("ReplicationSubsystem"), ExpansionHosts:WaitForChild("ReplicationReader"), ExpansionHosts:WaitForChild("ReplicationWriter")),
    entry("ScriptingSubsystem", "Expansion", 3, ExpansionSubsystems:WaitForChild("ScriptingSubsystem"), ExpansionHosts:WaitForChild("ScriptingReader"), ExpansionHosts:WaitForChild("ScriptingWriter")),
    entry("StateSyncSubsystem", "Expansion", 3, ExpansionSubsystems:WaitForChild("StateSyncSubsystem"), ExpansionHosts:WaitForChild("StateSyncReader"), ExpansionHosts:WaitForChild("StateSyncWriter")),
    entry("UISubsystem", "Expansion", 3, ExpansionSubsystems:WaitForChild("UISubsystem"), ExpansionHosts:WaitForChild("UIReader"), ExpansionHosts:WaitForChild("UIWriter")),

    entry("SimulationControlSubsystem", "Simulation", 4, SimulationSubsystems:WaitForChild("SimulationControlSubsystem"), SimulationHosts:WaitForChild("SimulationControlReader"), SimulationHosts:WaitForChild("SimulationControlWriter")),
    entry("StepDebuggerSubsystem", "Simulation", 4, SimulationSubsystems:WaitForChild("StepDebuggerSubsystem"), SimulationHosts:WaitForChild("StepDebuggerReader"), SimulationHosts:WaitForChild("StepDebuggerWriter")),
    entry("TimeScaleSubsystem", "Simulation", 4, SimulationSubsystems:WaitForChild("TimeScaleSubsystem"), SimulationHosts:WaitForChild("TimeScaleReader"), SimulationHosts:WaitForChild("TimeScaleWriter")),
}
