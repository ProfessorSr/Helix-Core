local PhysicsWriter = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))
local HostCommandSchemas = require(script.Parent.Parent:WaitForChild("HostCommandSchemas"))

local SERVICE_NAME = "Workspace"
local DOMAIN_NAME = "Physics"
local MAX_PENDING_COMMANDS = 256
local COMMAND_SCHEMAS = HostCommandSchemas.GetDomainSchemas(DOMAIN_NAME)
local COMMAND_HANDLERS = {
    SetGravity = function(self, payload)
        HostAdapterUtils.TryWriteProperty(self.Service, "Gravity", payload.Value)
    end,
    SetFallenPartsDestroyHeight = function(self, payload)
        HostAdapterUtils.TryWriteProperty(self.Service, "FallenPartsDestroyHeight", payload.Value)
    end,
}

function PhysicsWriter:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.PendingCommands = {}
    self.MaxPendingCommands = MAX_PENDING_COMMANDS
    self.LastWrite = nil
    self._enqueueSequence = 0
    self._droppedCommands = 0
end

function PhysicsWriter:Enqueue(command, payload)
    return HostAdapterUtils.EnqueueCommand(self.PendingCommands, command, payload, self.MaxPendingCommands, self)
end

function PhysicsWriter:Tick(dt)
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

function PhysicsWriter:Shutdown()
    self.PendingCommands = nil
    self.LastWrite = nil
    self.Service = nil
    self.Kernel = nil
end

return PhysicsWriter
