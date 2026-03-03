--[[
----------------------------------------------------------------
-- FILE: AccountSubsystem
-- LAYER: Enterprise
-- TYPE: Engine Subsystem Slot
-- LAST UPDATED (UTC): 2026-03-03T06:29:16Z
----------------------------------------------------------------
]]

local AccountSubsystem = {}

AccountSubsystem.Reader = nil
AccountSubsystem.Writer = nil

function AccountSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
end

function AccountSubsystem:Start()
end

function AccountSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function AccountSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return AccountSubsystem
