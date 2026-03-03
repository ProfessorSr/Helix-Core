--[[
----------------------------------------------------------------
-- FILE: InputSubsystem
-- TYPE: Core Engine Subsystem Slot
-- CROSS-ENGINE BASELINE
-- LAST UPDATED (UTC): 2026-03-03T06:23:40Z
----------------------------------------------------------------
]]

local InputSubsystem = {}
local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

-- Reader/Writer injected by RuntimeHost
InputSubsystem.Reader = nil
InputSubsystem.Writer = nil

local DEFAULT_BINDINGS = {
    MoveForward = "Key:W",
    MoveBackward = "Key:S",
    MoveLeft = "Key:A",
    MoveRight = "Key:D",
    Jump = "Key:Space",
    Sprint = "Key:LeftShift",
    Interact = "Key:E",
}

local function shallowCopy(input)
    local out = {}
    for key, value in pairs(input) do
        out[key] = value
    end
    return out
end

local function clearTable(input)
    for key in pairs(input) do
        input[key] = nil
    end
end

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

local function sortedBindingNames(bindings)
    local names = {}
    for actionName in pairs(bindings) do
        names[#names + 1] = actionName
    end
    table.sort(names)
    return names
end

local function sortedActionMap(actionMap)
    local list = {}
    for actionName, isActive in pairs(actionMap) do
        if isActive == true then
            list[#list + 1] = actionName
        end
    end
    table.sort(list)
    return list
end

local function buildInputFrame(self)
    local moveX = 0
    local moveY = 0
    if self.ActionDown.MoveRight then
        moveX += 1
    end
    if self.ActionDown.MoveLeft then
        moveX -= 1
    end
    if self.ActionDown.MoveForward then
        moveY += 1
    end
    if self.ActionDown.MoveBackward then
        moveY -= 1
    end

    return {
        ActionsDown = sortedActionMap(self.ActionDown),
        ActionsPressed = sortedActionMap(self.ActionPressed),
        ActionsReleased = sortedActionMap(self.ActionReleased),
        MoveX = moveX,
        MoveY = moveY,
        Jump = self.ActionDown.Jump == true,
        Sprint = self.ActionDown.Sprint == true,
        Interact = self.ActionPressed.Interact == true,
    }
end

function InputSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
    self.Bindings = shallowCopy(DEFAULT_BINDINGS)
    self.KeysDown = {}
    self.ActionDown = {}
    self.ActionPressed = {}
    self.ActionReleased = {}
    self.PreviousActionDown = {}

    local configuredSource = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        configuredSource = kernel.Config:Get("InputControlSource") or configuredSource
    end
    self.ControlSource = normalizeSource(configuredSource)
end

function InputSubsystem:Start()
    -- Bindings are initialized in Init; runtime can override via SetBindings/BindAction.
end

function InputSubsystem:SetBindings(bindings)
    if type(bindings) ~= "table" then
        return
    end

    self.Bindings = shallowCopy(bindings)
end

function InputSubsystem:GetBindings()
    return shallowCopy(self.Bindings)
end

function InputSubsystem:BindAction(actionName, keyToken)
    if type(actionName) ~= "string" or type(keyToken) ~= "string" then
        return false
    end

    self.Bindings[actionName] = keyToken
    return true
end

function InputSubsystem:UnbindAction(actionName)
    if type(actionName) ~= "string" then
        return false
    end

    self.Bindings[actionName] = nil
    return true
end

function InputSubsystem:IsActionDown(actionName)
    return self.ActionDown[actionName] == true
end

function InputSubsystem:WasActionPressed(actionName)
    return self.ActionPressed[actionName] == true
end

function InputSubsystem:WasActionReleased(actionName)
    return self.ActionReleased[actionName] == true
end

function InputSubsystem:GetKeysDown()
    return shallowCopy(self.KeysDown)
end

function InputSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function InputSubsystem:GetControlSource()
    return self.ControlSource
end

function InputSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX then
        local snapshot = nil
        if self.Reader and self.Reader.ReadSnapshot then
            snapshot = self.Reader:ReadSnapshot()
        end

        local keysDown = self.KeysDown
        clearTable(keysDown)
        if snapshot and snapshot.Data and type(snapshot.Data.KeysDown) == "table" then
            for index = 1, #snapshot.Data.KeysDown do
                local token = snapshot.Data.KeysDown[index]
                if type(token) == "string" then
                    keysDown[token] = true
                end
            end
        end

        clearTable(self.ActionDown)
        clearTable(self.ActionPressed)
        clearTable(self.ActionReleased)

        local bindingNames = sortedBindingNames(self.Bindings)
        for index = 1, #bindingNames do
            local actionName = bindingNames[index]
            local keyToken = self.Bindings[actionName]
            local isDown = keysDown[keyToken] == true
            local wasDown = self.PreviousActionDown[actionName] == true
            self.ActionDown[actionName] = isDown
            self.ActionPressed[actionName] = isDown and not wasDown
            self.ActionReleased[actionName] = (not isDown) and wasDown
            self.PreviousActionDown[actionName] = isDown
        end

        local timeAuthority = self.Kernel and self.Kernel.TimeAuthority
        local gameplayAuthority = self.Kernel and self.Kernel.GameplayAuthority
        if timeAuthority and timeAuthority.GetTickIndex and gameplayAuthority and gameplayAuthority.QueueInput then
            local tick = timeAuthority:GetTickIndex()
            gameplayAuthority:QueueInput("server", tick, buildInputFrame(self))
        end
    else
        clearTable(self.KeysDown)
        clearTable(self.ActionDown)
        clearTable(self.ActionPressed)
        clearTable(self.ActionReleased)
        clearTable(self.PreviousActionDown)
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function InputSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end

    self.KeysDown = {}
    self.ActionDown = {}
    self.ActionPressed = {}
    self.ActionReleased = {}
    self.PreviousActionDown = {}
end

return InputSubsystem
