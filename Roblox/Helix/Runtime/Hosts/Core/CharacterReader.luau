local CharacterReader = {}

local Players = game:GetService("Players")

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "Players"

function CharacterReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = Players
    self.LastSample = nil
end

function CharacterReader:Tick(dt)
    if not self.Service then
        return
    end

    local characterCount = 0
    local controlledCount = 0

    local players = self.Service:GetPlayers()
    for i = 1, #players do
        local player = players[i]
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local root = character:FindFirstChild("HumanoidRootPart")
            if humanoid and root and root:IsA("BasePart") then
                characterCount += 1
                if root:GetAttribute("HelixCharacterControlled") == true then
                    controlledCount += 1
                end
            end
        end
    end

    local sample = HostAdapterUtils.NewSnapshot("Character", SERVICE_NAME, dt)
    sample.Data.CharacterCount = characterCount
    sample.Data.ControlledCount = controlledCount
    HostAdapterUtils.CommitSnapshot(self, sample)
end

function CharacterReader:ReadSnapshot()
    return self.LastSample
end

function CharacterReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return CharacterReader
