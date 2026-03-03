--[[
----------------------------------------------------------------
-- FILE: StateSyncSubsystem
-- LAYER: Expansion
-- TYPE: Engine Subsystem Slot
-- LAST UPDATED (UTC): 2026-03-03T06:29:16Z
----------------------------------------------------------------
]]

local StateSyncSubsystem = {}

StateSyncSubsystem.Reader = nil
StateSyncSubsystem.Writer = nil

function StateSyncSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
end

function StateSyncSubsystem:Start()
end

function StateSyncSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function StateSyncSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return StateSyncSubsystem
