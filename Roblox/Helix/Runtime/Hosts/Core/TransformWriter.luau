local TransformWriter = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))
local HostCommandSchemas = require(script.Parent.Parent:WaitForChild("HostCommandSchemas"))

local SERVICE_NAME = "Workspace"
local DOMAIN_NAME = "Transform"
local MAX_PENDING_COMMANDS = 256
local COMMAND_SCHEMAS = HostCommandSchemas.GetDomainSchemas(DOMAIN_NAME)

local function isBasePart(instance)
    return instance and instance:IsA("BasePart")
end

local function collectBaseParts(root)
    local out = {}
    if not root then
        return out
    end

    if isBasePart(root) then
        out[#out + 1] = root
        return out
    end

    local descendants = root:GetDescendants()
    for index = 1, #descendants do
        local item = descendants[index]
        if isBasePart(item) then
            out[#out + 1] = item
        end
    end
    return out
end

local function resolveNeutralizationPolicy(kernel)
    if kernel and kernel.Config and kernel.Config.Get then
        local configured = kernel.Config:Get("HostPhysicsNeutralizationPolicy")
        if configured == "None" or configured == "AnchorOnly" or configured == "AnchorNoCollide" then
            return configured
        end
    end
    return "AnchorNoCollide"
end

local function hasRotationMatrix(payload)
    return type(payload.R00) == "number"
        and type(payload.R01) == "number"
        and type(payload.R02) == "number"
        and type(payload.R10) == "number"
        and type(payload.R11) == "number"
        and type(payload.R12) == "number"
        and type(payload.R20) == "number"
        and type(payload.R21) == "number"
        and type(payload.R22) == "number"
end

local function buildTransformCFrame(payload)
    local x = payload.PX
    local y = payload.PY
    local z = payload.PZ
    if hasRotationMatrix(payload) then
        return CFrame.new(
            x,
            y,
            z,
            payload.R00,
            payload.R01,
            payload.R02,
            payload.R10,
            payload.R11,
            payload.R12,
            payload.R20,
            payload.R21,
            payload.R22
        )
    end
    return CFrame.new(x, y, z)
end

local function getCommandBreakdown(commands)
    local out = {}
    for index = 1, #commands do
        local cmd = commands[index]
        if type(cmd) == "table" and type(cmd.Command) == "string" then
            out[cmd.Command] = (out[cmd.Command] or 0) + 1
        end
    end
    return out
end

local COMMAND_HANDLERS = {
    SetAttribute = function(self, payload)
        pcall(self.Service.SetAttribute, self.Service, payload.Key, payload.Value)
    end,
    BindEntityInstance = function(self, payload)
        self:RestoreHostPhysics(payload.EntityId)
        self.EntityBindings[payload.EntityId] = payload.Instance
        self:NeutralizeHostPhysics(payload.EntityId, payload.Instance)
    end,
    UnbindEntityInstance = function(self, payload)
        self:RestoreHostPhysics(payload.EntityId)
        self.EntityBindings[payload.EntityId] = nil
        self.EntityPartCache[payload.EntityId] = nil
    end,
    SetEntityTransform = function(self, payload)
        local instance = self.EntityBindings[payload.EntityId]
        if not instance then
            return
        end

        local targetCFrame = buildTransformCFrame(payload)
        local okHasPivot, _ = pcall(function()
            return instance:GetPivot()
        end)
        if okHasPivot then
            pcall(instance.PivotTo, instance, targetCFrame)
        else
            pcall(function()
                instance.CFrame = targetCFrame
            end)
        end
    end,
}

function TransformWriter:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.PendingCommands = {}
    self.EntityBindings = {}
    self.EntityPartCache = {}
    self.MaxPendingCommands = MAX_PENDING_COMMANDS
    self.LastWrite = nil
    self.HostPhysicsStateByEntity = {}
    self.NeutralizationPolicy = resolveNeutralizationPolicy(kernel)
    self._enqueueSequence = 0
    self._droppedCommands = 0
end

function TransformWriter:NeutralizeHostPhysics(entityId, instance)
    if self.NeutralizationPolicy == "None" then
        return
    end

    local parts = self.EntityPartCache[entityId]
    if not parts then
        parts = collectBaseParts(instance)
        self.EntityPartCache[entityId] = parts
    end
    if #parts == 0 then
        return
    end

    local saved = {}
    for index = 1, #parts do
        local part = parts[index]
        saved[#saved + 1] = {
            Part = part,
            Anchored = part.Anchored,
            CanCollide = part.CanCollide,
            CanTouch = part.CanTouch,
            CanQuery = part.CanQuery,
            AssemblyLinearVelocity = part.AssemblyLinearVelocity,
            AssemblyAngularVelocity = part.AssemblyAngularVelocity,
        }

        part.Anchored = true
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero

        if self.NeutralizationPolicy == "AnchorNoCollide" then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        end
    end

    self.HostPhysicsStateByEntity[entityId] = saved
end

function TransformWriter:RestoreHostPhysics(entityId)
    local saved = self.HostPhysicsStateByEntity[entityId]
    if not saved then
        return
    end

    for index = 1, #saved do
        local state = saved[index]
        local part = state.Part
        if part and part.Parent then
            part.Anchored = state.Anchored
            part.CanCollide = state.CanCollide
            part.CanTouch = state.CanTouch
            part.CanQuery = state.CanQuery
            part.AssemblyLinearVelocity = state.AssemblyLinearVelocity
            part.AssemblyAngularVelocity = state.AssemblyAngularVelocity
        end
    end

    self.HostPhysicsStateByEntity[entityId] = nil
end

function TransformWriter:Enqueue(command, payload)
    return HostAdapterUtils.EnqueueCommand(self.PendingCommands, command, payload, self.MaxPendingCommands, self)
end

function TransformWriter:Tick(dt)
    if not self.Service then
        return
    end

    local queueDropped = self._droppedCommands or 0
    self._droppedCommands = 0
    local commandBreakdown = getCommandBreakdown(self.PendingCommands)

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
        CommandBreakdown = commandBreakdown,
    })
end

function TransformWriter:Shutdown()
    if self.HostPhysicsStateByEntity then
        for entityId in pairs(self.HostPhysicsStateByEntity) do
            self:RestoreHostPhysics(entityId)
        end
    end

    self.PendingCommands = nil
    self.EntityBindings = nil
    self.EntityPartCache = nil
    self.HostPhysicsStateByEntity = nil
    self.LastWrite = nil
    self.Service = nil
    self.Kernel = nil
end

return TransformWriter
