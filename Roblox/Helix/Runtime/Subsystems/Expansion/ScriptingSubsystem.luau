local ScriptingSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

ScriptingSubsystem.Reader = nil
ScriptingSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function ScriptingSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
    self.BaseTimeout = 12

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("ScriptingControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function ScriptingSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function ScriptingSubsystem:GetControlSource()
    return self.ControlSource
end

function ScriptingSubsystem:Start()
end

function ScriptingSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX and self.Writer and self.Writer.Enqueue then
        local t = 0
        if self.Kernel and self.Kernel.TimeAuthority and self.Kernel.TimeAuthority.GetElapsedSeconds then
            t = self.Kernel.TimeAuthority:GetElapsedSeconds()
        end
        local timeout = self.BaseTimeout + math.floor((math.sin(t * 0.5) + 1) * 4)
        self.Writer:Enqueue("SetScriptTimeout", { Value = timeout })
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function ScriptingSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return ScriptingSubsystem
