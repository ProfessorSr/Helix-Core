local CharacterSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

CharacterSubsystem.Reader = nil
CharacterSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function CharacterSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HOST
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("CharacterControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function CharacterSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function CharacterSubsystem:GetControlSource()
    return self.ControlSource
end

function CharacterSubsystem:Start()
end

function CharacterSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.Writer and self.Writer.Enqueue then
        local gravity = 196.2
        if self.Kernel and self.Kernel.Config and self.Kernel.Config.Get then
            gravity = tonumber(self.Kernel.Config:Get("PhysicsGravity")) or gravity
        end

        self.Writer:Enqueue("SetCharacterControl", {
            HelixEnabled = self.ControlSource == SOURCE_HELIX,
            Gravity = gravity,
        })
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function CharacterSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return CharacterSubsystem
