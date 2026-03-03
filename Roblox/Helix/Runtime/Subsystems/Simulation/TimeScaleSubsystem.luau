local TimeScaleSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

TimeScaleSubsystem.Reader = nil
TimeScaleSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function TimeScaleSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("TimeScaleControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function TimeScaleSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function TimeScaleSubsystem:GetControlSource()
    return self.ControlSource
end

function TimeScaleSubsystem:Start()
end

function TimeScaleSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX then
        local simulation = self.Kernel and self.Kernel.Simulation
        local timeAuthority = self.Kernel and self.Kernel.TimeAuthority
        if simulation and timeAuthority and timeAuthority.GetElapsedSeconds then
            local t = timeAuthority:GetElapsedSeconds()
            simulation.TimeScale = 1 + math.sin(t * 0.2) * 0.15

            if self.Writer and self.Writer.Enqueue then
                self.Writer:Enqueue("SetTimeScale", { Value = simulation.TimeScale })
            end
        end
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function TimeScaleSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return TimeScaleSubsystem
