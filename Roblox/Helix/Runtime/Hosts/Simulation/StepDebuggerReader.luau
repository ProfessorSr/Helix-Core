local StepDebuggerReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "Stats"

function StepDebuggerReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function StepDebuggerReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("StepDebugger", SERVICE_NAME, dt)

    local okMem, mem = pcall(self.Service.GetTotalMemoryUsageMb, self.Service)
    if okMem then
        sample.Data.MemoryMB = mem
    end

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function StepDebuggerReader:ReadSnapshot()
    return self.LastSample
end

function StepDebuggerReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return StepDebuggerReader
