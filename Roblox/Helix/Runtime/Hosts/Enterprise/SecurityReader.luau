local SecurityReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "HttpService"

function SecurityReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function SecurityReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Security", SERVICE_NAME, dt)

    sample.Data.HttpEnabled = self.Service.HttpEnabled
    sample.Data.GenerateGUID = self.Service:GenerateGUID(false)

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function SecurityReader:ReadSnapshot()
    return self.LastSample
end

function SecurityReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return SecurityReader
