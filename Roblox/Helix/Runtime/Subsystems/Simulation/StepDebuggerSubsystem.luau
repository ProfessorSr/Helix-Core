--[[
----------------------------------------------------------------
-- FILE: StepDebuggerSubsystem
-- LAYER: Simulation
-- TYPE: Engine Subsystem Slot
-- LAST UPDATED (UTC): 2026-03-03T06:29:16Z
----------------------------------------------------------------
]]

local StepDebuggerSubsystem = {}

StepDebuggerSubsystem.Reader = nil
StepDebuggerSubsystem.Writer = nil

function StepDebuggerSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
end

function StepDebuggerSubsystem:Start()
end

function StepDebuggerSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function StepDebuggerSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return StepDebuggerSubsystem
