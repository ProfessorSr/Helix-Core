--[[
----------------------------------------------------------------
-- FILE: RuntimeEntrypoint
-- TYPE: Runtime Composition Root
-- LAST UPDATED (UTC): 2026-03-03T00:00:00Z
----------------------------------------------------------------
]]

local RunService = game:GetService("RunService")

local RuntimeHost = require(script.Parent:WaitForChild("RuntimeHost"))
local Scheduler = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Scheduler"))

local RuntimeEntrypoint = {}

local _started = false
local _heartbeatConnection = nil

local function buildBootstrapFromCore()
    local helixRoot = script.Parent.Parent
    local coreFolder = helixRoot:WaitForChild("Core")

    local HelixConfig = require(coreFolder:WaitForChild("HelixConfig"))
    local TimeAuthority = require(coreFolder:WaitForChild("Authorities"):WaitForChild("TimeAuthority"))
    local EventAuthority = require(coreFolder:WaitForChild("Authorities"):WaitForChild("EventAuthority"))

    HelixConfig:Initialize()
    HelixConfig:Lock()

    return {
        Kernel = {
            Config = HelixConfig,
            TimeAuthority = TimeAuthority,
            EventAuthority = EventAuthority,
        },
        RuntimeFolder = helixRoot:WaitForChild("Runtime"),
    }
end

local function resolveBootstrap()
    local parent = script.Parent.Parent.Parent
    local candidates = {
        parent:FindFirstChild("HelixBootstrap"),
        parent:FindFirstChild("HelixBootstrap.legacy"),
    }

    for _, candidate in ipairs(candidates) do
        if candidate and candidate:IsA("ModuleScript") then
            local ok, resolved = pcall(require, candidate)
            if ok and type(resolved) == "table" then
                return resolved
            end
        end
    end

    return buildBootstrapFromCore()
end

function RuntimeEntrypoint:Start()
    if _started then
        return
    end

    local bootstrap = resolveBootstrap()

    local kernel = bootstrap.Kernel
    local runtimeFolder = bootstrap.RuntimeFolder

    assert(kernel, "[RuntimeEntrypoint] Bootstrap missing Kernel")
    assert(runtimeFolder, "[RuntimeEntrypoint] Bootstrap missing RuntimeFolder")

    if kernel.EventAuthority and kernel.EventAuthority.Initialize then
        kernel.EventAuthority:Initialize()
    end

    RuntimeHost:Start(runtimeFolder, kernel)
    Scheduler:Start()

    _heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        Scheduler:Update(dt)
    end)

    _started = true
end

function RuntimeEntrypoint:Stop()
    if not _started then
        return
    end

    if _heartbeatConnection then
        _heartbeatConnection:Disconnect()
        _heartbeatConnection = nil
    end

    RuntimeHost:Stop()
    _started = false
end

return RuntimeEntrypoint
