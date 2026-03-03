local ServerDebugPanel = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UPDATE_INTERVAL = 0.25

local _running = false
local _connections = {}
local _guiByPlayer = {}
local _accumulator = 0

local function disconnectAll()
    for index = 1, #_connections do
        local conn = _connections[index]
        if conn then
            conn:Disconnect()
        end
    end
    _connections = {}
end

local function removeAllGui()
    for _, gui in pairs(_guiByPlayer) do
        if gui and gui.Parent then
            gui:Destroy()
        end
    end
    _guiByPlayer = {}
end

local function ensureGui(player)
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return nil
    end

    local gui = _guiByPlayer[player]
    if gui and gui.Parent == playerGui then
        return gui
    end

    if gui and gui.Parent then
        gui:Destroy()
    end

    gui = Instance.new("ScreenGui")
    gui.Name = "HelixDebugPanel"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 9999
    gui.IgnoreGuiInset = false
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "Root"
    frame.Size = UDim2.fromOffset(420, 190)
    frame.Position = UDim2.fromOffset(10, 10)
    frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -16, 0, 24)
    title.Position = UDim2.fromOffset(8, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.Code
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(160, 230, 255)
    title.TextSize = 16
    title.Text = "Helix Debug Panel"
    title.Parent = frame

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.Size = UDim2.new(1, -16, 1, -38)
    body.Position = UDim2.fromOffset(8, 30)
    body.BackgroundTransparency = 1
    body.Font = Enum.Font.Code
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextWrapped = false
    body.TextColor3 = Color3.fromRGB(230, 235, 245)
    body.TextSize = 14
    body.Text = ""
    body.Parent = frame

    _guiByPlayer[player] = gui
    return gui
end

local function formatPanelText(data)
    local overlay = data and data.Overlay or {}
    local diff = data and data.Diff or {}
    local profiler = data and data.Profiler or {}
    local net = data and data.Networking or {}
    local sections = profiler.Sections or {}
    local top = sections[1] or {}
    local rejectCount = (data and data.Rejects and #data.Rejects) or 0

    return table.concat({
        string.format("Tick: %s    Entities: %s    Collisions: %s", tostring(overlay.Tick or 0), tostring(overlay.EntityCount or 0), tostring(overlay.CollisionCount or 0)),
        string.format("StateHash: %s", tostring((data and data.Networking and data.Networking.LastStateHash) or "")),
        string.format("Diff  +%s  -%s  ~%s", tostring(diff.AddedCount or 0), tostring(diff.RemovedCount or 0), tostring(diff.ChangedCount or 0)),
        string.format("Net   Tick:%s Inputs:%s Rejects:%s", tostring(net.Tick or 0), tostring(net.InputCount or 0), tostring(net.RejectCount or 0)),
        string.format("Recent Reject Events: %s", tostring(rejectCount)),
        string.format("Profiler Total: %.3f ms", tonumber(profiler.TotalMs) or 0),
        string.format("Top Section: %s (%.3f ms)", tostring(top.Name or "n/a"), tonumber(top.DurationMs) or 0),
    }, "\n")
end

function ServerDebugPanel:Start(runtimeEntrypoint)
    if _running then
        return
    end
    _running = true

    local function onPlayer(player)
        ensureGui(player)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        onPlayer(player)
    end

    _connections[#_connections + 1] = Players.PlayerAdded:Connect(onPlayer)
    _connections[#_connections + 1] = Players.PlayerRemoving:Connect(function(player)
        local gui = _guiByPlayer[player]
        if gui and gui.Parent then
            gui:Destroy()
        end
        _guiByPlayer[player] = nil
    end)

    _connections[#_connections + 1] = RunService.Heartbeat:Connect(function(dt)
        _accumulator += dt
        if _accumulator < UPDATE_INTERVAL then
            return
        end
        _accumulator = 0

        if not runtimeEntrypoint or not runtimeEntrypoint.GetDebugInspectorData then
            return
        end

        local data = runtimeEntrypoint:GetDebugInspectorData()
        local text = formatPanelText(data)

        for _, player in ipairs(Players:GetPlayers()) do
            local gui = ensureGui(player)
            if gui then
                local frame = gui:FindFirstChild("Root")
                local body = frame and frame:FindFirstChild("Body")
                if body and body:IsA("TextLabel") then
                    body.Text = text
                end
            end
        end
    end)
end

function ServerDebugPanel:Stop()
    if not _running then
        return
    end
    _running = false
    _accumulator = 0
    disconnectAll()
    removeAllGui()
end

return ServerDebugPanel
