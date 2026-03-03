local ScriptingReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "ScriptContext"

function ScriptingReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function ScriptingReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Scripting", SERVICE_NAME, dt)

    sample.Data.ScriptContextReady = self.Service ~= nil

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function ScriptingReader:ReadSnapshot()
    return self.LastSample
end

function ScriptingReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return ScriptingReader
