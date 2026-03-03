--[[
----------------------------------------------------------------
-- FILE: PhysicsSubsystem
-- TYPE: Core Engine Subsystem Slot
-- CROSS-ENGINE BASELINE
-- LAST UPDATED (UTC): 2026-03-03T06:23:40Z
----------------------------------------------------------------
]]

local PhysicsSubsystem = {}

-- Reader/Writer injected by RuntimeHost
PhysicsSubsystem.Reader = nil
PhysicsSubsystem.Writer = nil

function PhysicsSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
end

function PhysicsSubsystem:Start()
    -- Called after kernel boot
end

function PhysicsSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function PhysicsSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return PhysicsSubsystem
