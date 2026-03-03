local TimeSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

TimeSubsystem.Reader = nil
TimeSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function TimeSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("TimeControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function TimeSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function TimeSubsystem:GetControlSource()
    return self.ControlSource
end

function TimeSubsystem:Start()
end

function TimeSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX and self.Writer and self.Writer.Enqueue then
        local tick = 0
        local elapsed = 0
        local fixedStep = 0
        if self.Kernel and self.Kernel.TimeAuthority then
            if self.Kernel.TimeAuthority.GetTickIndex then
                tick = self.Kernel.TimeAuthority:GetTickIndex()
            end
            if self.Kernel.TimeAuthority.GetElapsedSeconds then
                elapsed = self.Kernel.TimeAuthority:GetElapsedSeconds()
            end
            if self.Kernel.TimeAuthority.GetFixedStep then
                fixedStep = self.Kernel.TimeAuthority:GetFixedStep()
            end
        end

        self.Writer:Enqueue("SetTimeAttribute", { Key = "HelixTick", Value = tick })
        self.Writer:Enqueue("SetTimeAttribute", { Key = "HelixElapsed", Value = elapsed })
        self.Writer:Enqueue("SetTimeAttribute", { Key = "HelixFixedStep", Value = fixedStep })
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function TimeSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return TimeSubsystem
