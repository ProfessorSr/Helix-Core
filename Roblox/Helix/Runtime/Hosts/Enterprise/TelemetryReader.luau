local TelemetryReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "LogService"

function TelemetryReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function TelemetryReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Telemetry", SERVICE_NAME, dt)

    sample.Data.MessageCount = 0
    local okHistory, history = pcall(self.Service.GetLogHistory, self.Service)
    if okHistory and history then
        sample.Data.MessageCount = #history
    end

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function TelemetryReader:ReadSnapshot()
    return self.LastSample
end

function TelemetryReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return TelemetryReader
