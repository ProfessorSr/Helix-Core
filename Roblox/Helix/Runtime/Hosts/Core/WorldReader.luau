local WorldReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "Workspace"

function WorldReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function WorldReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("World", SERVICE_NAME, dt)

    sample.Data.Gravity = self.Service.Gravity
    sample.Data.FallenPartsDestroyHeight = self.Service.FallenPartsDestroyHeight

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function WorldReader:ReadSnapshot()
    return self.LastSample
end

function WorldReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return WorldReader
