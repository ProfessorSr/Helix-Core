local CameraWriter = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))
local HostCommandSchemas = require(script.Parent.Parent:WaitForChild("HostCommandSchemas"))

local SERVICE_NAME = "Workspace"
local DOMAIN_NAME = "Camera"
local MAX_PENDING_COMMANDS = 256
local COMMAND_SCHEMAS = HostCommandSchemas.GetDomainSchemas(DOMAIN_NAME)
local COMMAND_HANDLERS = {
    SetFieldOfView = function(self, payload)
        local cam = self.Service.CurrentCamera
        if cam then
            HostAdapterUtils.TryWriteProperty(cam, "FieldOfView", payload.Value)
        end
    end,
    SetCameraType = function(self, payload)
        local cam = self.Service.CurrentCamera
        if cam then
            local value = payload.Value
            if type(value) == "string" and Enum.CameraType[value] ~= nil then
                value = Enum.CameraType[value]
            end
            HostAdapterUtils.TryWriteProperty(cam, "CameraType", value)
        end
    end,
    SetCFrame = function(self, payload)
        local cam = self.Service.CurrentCamera
        if cam then
            HostAdapterUtils.TryWriteProperty(cam, "CFrame", payload.Value)
        end
    end,
    SetPose = function(self, payload)
        local cam = self.Service.CurrentCamera
        if not cam then
            return
        end

        local position = Vector3.new(payload.PX, payload.PY, payload.PZ)
        local lookAt = Vector3.new(payload.LX, payload.LY, payload.LZ)
        HostAdapterUtils.TryWriteProperty(cam, "CFrame", CFrame.new(position, lookAt))
    end,
}

function CameraWriter:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.PendingCommands = {}
    self.MaxPendingCommands = MAX_PENDING_COMMANDS
    self.LastWrite = nil
    self._enqueueSequence = 0
    self._droppedCommands = 0
end

function CameraWriter:Enqueue(command, payload)
    return HostAdapterUtils.EnqueueCommand(self.PendingCommands, command, payload, self.MaxPendingCommands, self)
end

function CameraWriter:Tick(dt)
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

function CameraWriter:Shutdown()
    self.PendingCommands = nil
    self.LastWrite = nil
    self.Service = nil
    self.Kernel = nil
end

return CameraWriter
