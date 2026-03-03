--[[
----------------------------------------------------------------
-- FILE: CameraSubsystem
-- TYPE: Core Engine Subsystem Slot
-- CROSS-ENGINE BASELINE
-- LAST UPDATED (UTC): 2026-03-03T06:23:40Z
----------------------------------------------------------------
]]

local CameraSubsystem = {}
local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

-- Reader/Writer injected by RuntimeHost
CameraSubsystem.Reader = nil
CameraSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HELIX then
        return SOURCE_HELIX
    end
    return SOURCE_HOST
end

function CameraSubsystem:ApplyControlSourceTransition()
    if not self.Writer or not self.Writer.Enqueue then
        return
    end

    if self._appliedSource == self.ControlSource then
        return
    end

    if self.ControlSource == SOURCE_HELIX then
        self.Writer:Enqueue("SetCameraType", { Value = self.State.CameraType })
        self.Writer:Enqueue("SetFieldOfView", { Value = self.State.FieldOfView })
    else
        -- Hand control back to host/default camera behavior.
        self.Writer:Enqueue("SetCameraType", { Value = "Custom" })
    end

    self._appliedSource = self.ControlSource
end

function CameraSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    self.State = {
        Radius = 16,
        Height = 8,
        BobAmplitude = 1.25,
        OrbitSpeed = 0.4,
        BobSpeed = 0.8,
        LookAtX = 0,
        LookAtY = 4,
        LookAtZ = 0,
        FieldOfView = 70,
        CameraType = "Scriptable",
    }

    local configuredSource = SOURCE_HOST
    if kernel and kernel.Config and kernel.Config.Get then
        configuredSource = kernel.Config:Get("CameraControlSource") or configuredSource
    end
    self.ControlSource = normalizeSource(configuredSource)
    self._appliedSource = nil
end

function CameraSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function CameraSubsystem:GetControlSource()
    return self.ControlSource
end

function CameraSubsystem:Start()
    self:ApplyControlSourceTransition()
end

function CameraSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    self:ApplyControlSourceTransition()

    if self.ControlSource == SOURCE_HELIX and self.Writer and self.Writer.Enqueue then
        local timeAuthority = self.Kernel and self.Kernel.TimeAuthority
        local t = 0
        if timeAuthority and timeAuthority.GetElapsedSeconds then
            t = timeAuthority:GetElapsedSeconds()
        end

        local x = math.cos(t * self.State.OrbitSpeed) * self.State.Radius
        local z = math.sin(t * self.State.OrbitSpeed) * self.State.Radius
        local y = self.State.Height + math.sin(t * self.State.BobSpeed) * self.State.BobAmplitude

        self.Writer:Enqueue("SetFieldOfView", { Value = self.State.FieldOfView })
        self.Writer:Enqueue("SetPose", {
            PX = x,
            PY = y,
            PZ = z,
            LX = self.State.LookAtX,
            LY = self.State.LookAtY,
            LZ = self.State.LookAtZ,
        })
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function CameraSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return CameraSubsystem
