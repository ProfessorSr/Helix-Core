--[[
----------------------------------------------------------------
-- FILE: PersistenceSubsystem
-- LAYER: Enterprise
-- TYPE: Engine Subsystem Slot
-- LAST UPDATED (UTC): 2026-03-03T06:29:16Z
----------------------------------------------------------------
]]

local PersistenceSubsystem = {}

PersistenceSubsystem.Reader = nil
PersistenceSubsystem.Writer = nil

function PersistenceSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
end

function PersistenceSubsystem:Start()
end

function PersistenceSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function PersistenceSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return PersistenceSubsystem
