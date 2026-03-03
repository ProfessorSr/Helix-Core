--[[
----------------------------------------------------------------
-- FILE: TimeScaleSubsystem
-- LAYER: Simulation
-- TYPE: Engine Subsystem Slot
-- LAST UPDATED (UTC): 2026-03-03T06:29:16Z
----------------------------------------------------------------
]]

local TimeScaleSubsystem = {}

TimeScaleSubsystem.Reader = nil
TimeScaleSubsystem.Writer = nil

function TimeScaleSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
end

function TimeScaleSubsystem:Start()
end

function TimeScaleSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
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
