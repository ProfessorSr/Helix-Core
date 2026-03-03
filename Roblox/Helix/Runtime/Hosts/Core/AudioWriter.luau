local AudioWriter = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))
local HostCommandSchemas = require(script.Parent.Parent:WaitForChild("HostCommandSchemas"))

local SERVICE_NAME = "SoundService"
local DOMAIN_NAME = "Audio"
local MAX_PENDING_COMMANDS = 256
local COMMAND_SCHEMAS = HostCommandSchemas.GetDomainSchemas(DOMAIN_NAME)
local COMMAND_HANDLERS = {
    SetVolume = function(self, payload)
        -- SoundService has no global Volume property; preserve intent as host metadata.
        self.Service:SetAttribute("HelixMasterVolume", payload.Value)
    end,
    SetAmbientReverb = function(self, payload)
        local value = payload.Value
        if type(value) == "string" and Enum.ReverbType[value] ~= nil then
            value = Enum.ReverbType[value]
        end
        HostAdapterUtils.TryWriteProperty(self.Service, "AmbientReverb", value)
    end,
    SetBusLevel = function(self, payload)
        local key = "HelixBus_" .. payload.Bus
        pcall(self.Service.SetAttribute, self.Service, key, payload.Value)
    end,
}

function AudioWriter:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.PendingCommands = {}
    self.MaxPendingCommands = MAX_PENDING_COMMANDS
    self.LastWrite = nil
    self._enqueueSequence = 0
    self._droppedCommands = 0
end

function AudioWriter:Enqueue(command, payload)
    return HostAdapterUtils.EnqueueCommand(self.PendingCommands, command, payload, self.MaxPendingCommands, self)
end

function AudioWriter:Tick(dt)
    if not self.Service then
        return
    end

    local queueDropped = self._droppedCommands or 0
    self._droppedCommands = 0

    local processed, dropped = HostAdapterUtils.ProcessValidatedCommands(
        self.PendingCommands,
        COMMAND_SCHEMAS,
        COMMAND_HANDLERS,
        self
    )

    self.PendingCommands = {}
    self.LastWrite = HostAdapterUtils.NewWriteMeta(DOMAIN_NAME, SERVICE_NAME, dt, {
        ProcessedCommands = processed,
        DroppedCommands = queueDropped + dropped,
    })
end

function AudioWriter:Shutdown()
    self.PendingCommands = nil
    self.LastWrite = nil
    self.Service = nil
    self.Kernel = nil
end

return AudioWriter
