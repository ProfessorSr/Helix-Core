local AssetReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "ContentProvider"

function AssetReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function AssetReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Asset", SERVICE_NAME, dt)

    sample.Data.RequestQueueSize = self.Service.RequestQueueSize

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function AssetReader:ReadSnapshot()
    return self.LastSample
end

function AssetReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return AssetReader
