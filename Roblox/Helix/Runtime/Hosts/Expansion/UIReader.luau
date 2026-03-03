local UIReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "StarterGui"

function UIReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function UIReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("UI", SERVICE_NAME, dt)

    local okChildren, children = pcall(self.Service.GetChildren, self.Service)
    if okChildren and children then
        sample.Data.ChildCount = #children
    end

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function UIReader:ReadSnapshot()
    return self.LastSample
end

function UIReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return UIReader
