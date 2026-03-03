local TimeScaleReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "RunService"

function TimeScaleReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function TimeScaleReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("TimeScale", SERVICE_NAME, dt)

    sample.Data.IsServer = self.Service:IsServer()
    sample.Data.IsStudio = self.Service:IsStudio()

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function TimeScaleReader:ReadSnapshot()
    return self.LastSample
end

function TimeScaleReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return TimeScaleReader
