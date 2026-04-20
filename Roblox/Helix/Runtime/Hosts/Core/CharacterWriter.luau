local CharacterWriter = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))
local HostCommandSchemas = require(script.Parent.Parent:WaitForChild("HostCommandSchemas"))

local SERVICE_NAME = "Players"
local DOMAIN_NAME = "Character"
local MAX_PENDING_COMMANDS = 256
local COMMAND_SCHEMAS = HostCommandSchemas.GetDomainSchemas(DOMAIN_NAME)

local ATTACHMENT_NAME = "HelixCharacterAttachment"
local FORCE_NAME = "HelixCharacterGravityForce"

local function getRootPart(player)
    local character = player and player.Character
    if not character then
        return nil
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    return nil
end

local function ensureAttachment(root)
    local attachment = root:FindFirstChild(ATTACHMENT_NAME)
    if attachment and attachment:IsA("Attachment") then
        return attachment
    end
    attachment = Instance.new("Attachment")
    attachment.Name = ATTACHMENT_NAME
    attachment.Parent = root
    return attachment
end

local function ensureForce(root, attachment)
    local force = root:FindFirstChild(FORCE_NAME)
    if force and force:IsA("VectorForce") then
        return force
    end
    force = Instance.new("VectorForce")
    force.Name = FORCE_NAME
    force.RelativeTo = Enum.ActuatorRelativeTo.World
    force.ApplyAtCenterOfMass = true
    force.Attachment0 = attachment
    force.Parent = root
    return force
end

local function disableOnRoot(root)
    local force = root:FindFirstChild(FORCE_NAME)
    if force and force:IsA("VectorForce") then
        force:Destroy()
    end
    root:SetAttribute("HelixCharacterControlled", false)
end

local COMMAND_HANDLERS = {
    SetCharacterControl = function(self, payload)
        self.TargetHelixEnabled = payload.HelixEnabled == true
        self.TargetGravity = math.max(0, tonumber(payload.Gravity) or self.TargetGravity or 196.2)
    end,
}

function CharacterWriter:Initialize(kernel)
    self.Kernel = kernel
    self.Service = Players
    self.PendingCommands = {}
    self.MaxPendingCommands = MAX_PENDING_COMMANDS
    self.LastWrite = nil
    self.TargetHelixEnabled = false
    self.TargetGravity = 196.2
    self._enqueueSequence = 0
    self._droppedCommands = 0
end

function CharacterWriter:Enqueue(command, payload)
    return HostAdapterUtils.EnqueueCommand(self.PendingCommands, command, payload, self.MaxPendingCommands, self)
end

function CharacterWriter:Tick(dt)
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

    local workspaceGravity = tonumber(Workspace.Gravity) or 196.2
    local desiredGravity = math.max(0, tonumber(self.TargetGravity) or 196.2)

    local players = self.Service:GetPlayers()
    for i = 1, #players do
        local root = getRootPart(players[i])
        if root then
            if self.TargetHelixEnabled then
                local attachment = ensureAttachment(root)
                local force = ensureForce(root, attachment)
                local mass = math.max(0, tonumber(root.AssemblyMass) or 0)
                local compensation = (workspaceGravity - desiredGravity) * mass
                force.Force = Vector3.new(0, compensation, 0)
                root:SetAttribute("HelixCharacterControlled", true)
            else
                disableOnRoot(root)
            end
        end
    end

    self.LastWrite = HostAdapterUtils.NewWriteMeta(DOMAIN_NAME, SERVICE_NAME, dt, {
        ProcessedCommands = processed,
        DroppedCommands = queueDropped + dropped,
        HelixEnabled = self.TargetHelixEnabled,
        Gravity = desiredGravity,
    })
end

function CharacterWriter:Shutdown()
    if self.Service then
        local players = self.Service:GetPlayers()
        for i = 1, #players do
            local root = getRootPart(players[i])
            if root then
                disableOnRoot(root)
            end
        end
    end

    self.PendingCommands = nil
    self.LastWrite = nil
    self.Service = nil
    self.Kernel = nil
end

return CharacterWriter
