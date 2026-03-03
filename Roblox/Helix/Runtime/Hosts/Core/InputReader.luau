local InputReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "UserInputService"

local function isGamepadInputType(inputType)
    if type(inputType) ~= "EnumItem" then
        return false
    end

    local name = inputType.Name
    return string.sub(name, 1, 7) == "Gamepad"
end

local function inputToToken(input)
    if not input then
        return nil
    end

    local inputType = input.UserInputType
    if inputType == Enum.UserInputType.Keyboard then
        local keyCode = input.KeyCode
        if keyCode and keyCode ~= Enum.KeyCode.Unknown then
            return "Key:" .. keyCode.Name
        end
        return nil
    end

    if inputType == Enum.UserInputType.MouseButton1 then
        return "Mouse:Button1"
    end
    if inputType == Enum.UserInputType.MouseButton2 then
        return "Mouse:Button2"
    end
    if inputType == Enum.UserInputType.MouseButton3 then
        return "Mouse:Button3"
    end

    if isGamepadInputType(inputType) then
        local keyCode = input.KeyCode
        if keyCode and keyCode ~= Enum.KeyCode.Unknown then
            return inputType.Name .. ":" .. keyCode.Name
        end

        return inputType.Name
    end

    return nil
end

local function sortedKeysDown(keysDownMap)
    local list = {}
    for token, isDown in pairs(keysDownMap) do
        if isDown then
            list[#list + 1] = token
        end
    end
    table.sort(list)
    return list
end

function InputReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
    self.KeysDown = {}
    self.Connections = {}

    if self.Service then
        self.Connections[#self.Connections + 1] = self.Service.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then
                return
            end

            local token = inputToToken(input)
            if token then
                self.KeysDown[token] = true
            end
        end)

        self.Connections[#self.Connections + 1] = self.Service.InputEnded:Connect(function(input, _gameProcessed)
            local token = inputToToken(input)
            if token then
                self.KeysDown[token] = nil
            end
        end)
    end
end

function InputReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Input", SERVICE_NAME, dt)

    sample.Data.KeyboardEnabled = self.Service.KeyboardEnabled
    sample.Data.MouseEnabled = self.Service.MouseEnabled
    sample.Data.TouchEnabled = self.Service.TouchEnabled
    sample.Data.LastInputType = tostring(self.Service:GetLastInputType())
    sample.Data.KeysDown = sortedKeysDown(self.KeysDown)
    sample.Data.KeyCount = #sample.Data.KeysDown

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function InputReader:ReadSnapshot()
    return self.LastSample
end

function InputReader:Shutdown()
    if self.Connections then
        for index = 1, #self.Connections do
            local connection = self.Connections[index]
            if connection then
                connection:Disconnect()
            end
        end
    end

    self.LastSample = nil
    self.KeysDown = nil
    self.Connections = nil
    self.Service = nil
    self.Kernel = nil
end

return InputReader
