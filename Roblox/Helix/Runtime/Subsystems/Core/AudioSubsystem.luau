--[[
----------------------------------------------------------------
-- FILE: AudioSubsystem
-- TYPE: Core Engine Subsystem Slot
-- CROSS-ENGINE BASELINE
-- LAST UPDATED (UTC): 2026-03-03T06:23:40Z
----------------------------------------------------------------
]]

local AudioSubsystem = {}
local DEFAULT_REVERB = "NoReverb"
local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

-- Reader/Writer injected by RuntimeHost
AudioSubsystem.Reader = nil
AudioSubsystem.Writer = nil

local function clamp01(value)
    if type(value) ~= "number" then
        return 0
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function smoothToward(current, target, rate, dt)
    local alpha = math.min(1, math.max(0, rate * (dt or 0)))
    return current + (target - current) * alpha
end

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function AudioSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    self.Mixer = {
        SmoothingRate = 12,
        Muted = false,
        AmbientReverb = DEFAULT_REVERB,
        Target = {
            Master = 1.0,
            Music = 1.0,
            SFX = 1.0,
            Ambience = 1.0,
        },
        Current = {
            Master = 1.0,
            Music = 1.0,
            SFX = 1.0,
            Ambience = 1.0,
        },
    }

    local configuredSource = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        configuredSource = kernel.Config:Get("AudioControlSource") or configuredSource
    end
    self.ControlSource = normalizeSource(configuredSource)
end

function AudioSubsystem:SetBusLevel(busName, level)
    if not self.Mixer or not self.Mixer.Target or type(busName) ~= "string" then
        return false
    end
    if self.Mixer.Target[busName] == nil then
        return false
    end

    self.Mixer.Target[busName] = clamp01(level)
    return true
end

function AudioSubsystem:GetBusLevel(busName)
    if not self.Mixer or not self.Mixer.Current or type(busName) ~= "string" then
        return nil
    end
    return self.Mixer.Current[busName]
end

function AudioSubsystem:SetMuted(value)
    self.Mixer.Muted = value == true
end

function AudioSubsystem:SetAmbientReverb(reverbName)
    if type(reverbName) ~= "string" or reverbName == "" then
        return false
    end
    self.Mixer.AmbientReverb = reverbName
    return true
end

function AudioSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function AudioSubsystem:GetControlSource()
    return self.ControlSource
end

function AudioSubsystem:Start()
    if not self.Writer or not self.Writer.Enqueue then
        return
    end

    self.Writer:Enqueue("SetAmbientReverb", { Value = self.Mixer.AmbientReverb })
end

function AudioSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX and self.Writer and self.Writer.Enqueue and self.Mixer then
        local current = self.Mixer.Current
        local target = self.Mixer.Target
        local rate = self.Mixer.SmoothingRate

        current.Master = smoothToward(current.Master, target.Master, rate, dt)
        current.Music = smoothToward(current.Music, target.Music, rate, dt)
        current.SFX = smoothToward(current.SFX, target.SFX, rate, dt)
        current.Ambience = smoothToward(current.Ambience, target.Ambience, rate, dt)

        local master = current.Master
        if self.Mixer.Muted then
            master = 0
        end

        self.Writer:Enqueue("SetVolume", { Value = clamp01(master) })
        self.Writer:Enqueue("SetBusLevel", { Bus = "Master", Value = clamp01(current.Master) })
        self.Writer:Enqueue("SetBusLevel", { Bus = "Music", Value = clamp01(current.Music) })
        self.Writer:Enqueue("SetBusLevel", { Bus = "SFX", Value = clamp01(current.SFX) })
        self.Writer:Enqueue("SetBusLevel", { Bus = "Ambience", Value = clamp01(current.Ambience) })
        self.Writer:Enqueue("SetAmbientReverb", { Value = self.Mixer.AmbientReverb })
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function AudioSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end

    self.Mixer = nil
end

return AudioSubsystem
