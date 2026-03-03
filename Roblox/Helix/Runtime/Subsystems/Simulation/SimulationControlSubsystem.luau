--[[
----------------------------------------------------------------
-- FILE: SimulationControlSubsystem
-- LAYER: Simulation
-- TYPE: Engine Subsystem Slot
-- LAST UPDATED (UTC): 2026-03-03T06:29:16Z
----------------------------------------------------------------
]]

local SimulationControlSubsystem = {}

SimulationControlSubsystem.Reader = nil
SimulationControlSubsystem.Writer = nil

function SimulationControlSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
end

function SimulationControlSubsystem:Start()
end

function SimulationControlSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function SimulationControlSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return SimulationControlSubsystem
