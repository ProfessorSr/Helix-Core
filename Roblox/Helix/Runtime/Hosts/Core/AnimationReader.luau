local AnimationReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "AnimationClipProvider"

function AnimationReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function AnimationReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Animation", SERVICE_NAME, dt)

    sample.Data.ProviderReady = self.Service ~= nil

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function AnimationReader:ReadSnapshot()
    return self.LastSample
end

function AnimationReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return AnimationReader
