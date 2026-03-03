local PolicyReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "PolicyService"

function PolicyReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function PolicyReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Policy", SERVICE_NAME, dt)

    sample.Data.PolicyServiceReady = self.Service ~= nil

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function PolicyReader:ReadSnapshot()
    return self.LastSample
end

function PolicyReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return PolicyReader
