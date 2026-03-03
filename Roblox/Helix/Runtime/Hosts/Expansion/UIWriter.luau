local UIWriter = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))
local HostCommandSchemas = require(script.Parent.Parent:WaitForChild("HostCommandSchemas"))

local SERVICE_NAME = "StarterGui"
local RUN_SERVICE_NAME = "RunService"
local DOMAIN_NAME = "UI"
local MAX_PENDING_COMMANDS = 256
local COMMAND_SCHEMAS = HostCommandSchemas.GetDomainSchemas(DOMAIN_NAME)
local COMMAND_HANDLERS = {
    SetAttribute = function(self, payload)
        pcall(self.Service.SetAttribute, self.Service, payload.Key, payload.Value)
    end,
    SetCoreGuiEnabled = function(self, payload)
        if not self.IsClient then
            -- Server cannot call SetCoreGuiEnabled; persist intended state for observability.
            pcall(self.Service.SetAttribute, self.Service, "HelixCoreGuiEnabled", payload.Enabled)
            return
        end

        local guiType = payload.GuiType
        if type(guiType) == "string" and Enum.CoreGuiType[guiType] ~= nil then
            guiType = Enum.CoreGuiType[guiType]
        end
        pcall(self.Service.SetCoreGuiEnabled, self.Service, guiType, payload.Enabled)
    end,
}

function UIWriter:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    local runService = HostAdapterUtils.TryGetService(RUN_SERVICE_NAME)
    self.IsClient = runService and runService:IsClient() or false
    self.PendingCommands = {}
    self.MaxPendingCommands = MAX_PENDING_COMMANDS
    self.LastWrite = nil
    self._enqueueSequence = 0
    self._droppedCommands = 0
end

function UIWriter:Enqueue(command, payload)
    return HostAdapterUtils.EnqueueCommand(self.PendingCommands, command, payload, self.MaxPendingCommands, self)
end

function UIWriter:Tick(dt)
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

function UIWriter:Shutdown()
    self.PendingCommands = nil
    self.LastWrite = nil
    self.IsClient = nil
    self.Service = nil
    self.Kernel = nil
end

return UIWriter
