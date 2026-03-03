local StateSyncReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "ReplicatedStorage"

function StateSyncReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function StateSyncReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("StateSync", SERVICE_NAME, dt)

    local okChildren, children = pcall(self.Service.GetChildren, self.Service)
    if okChildren and children then
        sample.Data.ChildCount = #children
    end

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function StateSyncReader:ReadSnapshot()
    return self.LastSample
end

function StateSyncReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return StateSyncReader
