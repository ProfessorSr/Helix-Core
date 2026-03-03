local PhysicsReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "PhysicsService"

function PhysicsReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function PhysicsReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Physics", SERVICE_NAME, dt)

    local okGroups, groups = pcall(self.Service.GetRegisteredCollisionGroups, self.Service)
    if okGroups and groups then
        sample.Data.CollisionGroupCount = #groups
    end

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function PhysicsReader:ReadSnapshot()
    return self.LastSample
end

function PhysicsReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return PhysicsReader
