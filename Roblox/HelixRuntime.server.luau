local HelixRoot = script.Parent:WaitForChild("Helix")
local RuntimeFolder = HelixRoot:WaitForChild("Runtime")

local BootState = require(RuntimeFolder:WaitForChild("BootState"))

local RuntimeEntrypoint = require(
    RuntimeFolder
        :WaitForChild("RuntimeEntrypoint")
)
local ServerDebugPanel = require(
    RuntimeFolder
        :WaitForChild("Tools")
        :WaitForChild("ServerDebugPanel")
)

local cameraSourceConnection = nil
local subsystemSourceConnection = nil
local debugPanelEnabled = true

if BootState:IsReady() then
    return
end

BootState:MarkStarting()
script:SetAttribute("HelixBootStarted", true)
script:SetAttribute("HelixReady", false)
HelixRoot:SetAttribute("HelixReady", false)

local ok, err = pcall(function()
    RuntimeEntrypoint:Start()
end)

if not ok then
    BootState:MarkFailed(err)
    script:SetAttribute("HelixBootFailed", true)
    script:SetAttribute("HelixBootError", tostring(err))
    error(string.format("[HelixRuntime] Boot failed: %s", tostring(err)))
end

BootState:MarkReady()
script:SetAttribute("HelixReady", true)
HelixRoot:SetAttribute("HelixReady", true)
script:SetAttribute("HelixDebugPanelEnabled", true)

if debugPanelEnabled then
    ServerDebugPanel:Start(RuntimeEntrypoint)
end

local initialSource = RuntimeEntrypoint:GetCameraControlSource() or "Host"
script:SetAttribute("HelixCameraControlSource", initialSource)
HelixRoot:SetAttribute("HelixCameraControlSource", initialSource)
local sources = RuntimeEntrypoint:GetSubsystemControlSources()
local uniformSource = nil
for _, source in pairs(sources) do
    if type(source) == "string" then
        if uniformSource == nil then
            uniformSource = source
        elseif uniformSource ~= source then
            uniformSource = "Mixed"
            break
        end
    end
end
if uniformSource == nil then
    uniformSource = "Helix"
end
script:SetAttribute("HelixSubsystemControlSource", uniformSource)
HelixRoot:SetAttribute("HelixSubsystemControlSource", uniformSource)

if cameraSourceConnection then
    cameraSourceConnection:Disconnect()
    cameraSourceConnection = nil
end

if subsystemSourceConnection then
    subsystemSourceConnection:Disconnect()
    subsystemSourceConnection = nil
end

cameraSourceConnection = script:GetAttributeChangedSignal("HelixCameraControlSource"):Connect(function()
    local source = script:GetAttribute("HelixCameraControlSource")
    if type(source) ~= "string" then
        return
    end

    if RuntimeEntrypoint:SetCameraControlSource(source) then
        local normalized = RuntimeEntrypoint:GetCameraControlSource() or source
        script:SetAttribute("HelixCameraControlSource", normalized)
        HelixRoot:SetAttribute("HelixCameraControlSource", normalized)
    end
end)

subsystemSourceConnection = script:GetAttributeChangedSignal("HelixSubsystemControlSource"):Connect(function()
    local source = script:GetAttribute("HelixSubsystemControlSource")
    if type(source) ~= "string" then
        return
    end
    if source == "Mixed" then
        return
    end

    local changed = RuntimeEntrypoint:SetSubsystemControlSource(source)
    if changed and changed > 0 then
        HelixRoot:SetAttribute("HelixSubsystemControlSource", source)
    end
end)

script:GetAttributeChangedSignal("HelixDebugPanelEnabled"):Connect(function()
    local enabled = script:GetAttribute("HelixDebugPanelEnabled")
    if enabled == true then
        ServerDebugPanel:Start(RuntimeEntrypoint)
    else
        ServerDebugPanel:Stop()
    end
end)
