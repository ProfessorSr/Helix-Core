local PolicySubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

PolicySubsystem.Reader = nil
PolicySubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

local function getTimeData(kernel)
    local tick = 0
    local elapsed = 0
    local timeAuthority = kernel and kernel.TimeAuthority
    if timeAuthority then
        if timeAuthority.GetTickIndex then
            tick = timeAuthority:GetTickIndex()
        end
        if timeAuthority.GetElapsedSeconds then
            elapsed = timeAuthority:GetElapsedSeconds()
        end
    end
    return tick, elapsed
end

function PolicySubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("PolicyControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function PolicySubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function PolicySubsystem:GetControlSource()
    return self.ControlSource
end

function PolicySubsystem:Start()
end

function PolicySubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX and self.Writer and self.Writer.Enqueue then
        local tick, elapsed = getTimeData(self.Kernel)
        self.Writer:Enqueue("SetAttribute", { Key = "HelixTick", Value = tick })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixElapsed", Value = elapsed })

        local sample = nil
        if self.Reader and self.Reader.ReadSnapshot then
            sample = self.Reader:ReadSnapshot()
        end
        if sample and sample.Data then
            self.Writer:Enqueue("SetAttribute", { Key = "HelixDataSignature", Value = sample.Signature or "" })
        end
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function PolicySubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return PolicySubsystem
