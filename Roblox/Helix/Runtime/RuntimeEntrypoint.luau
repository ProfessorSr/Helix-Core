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
local Registry = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Registry"))
local HostAdapterUtils = require(script.Parent:WaitForChild("Hosts"):WaitForChild("HostAdapterUtils"))
local WorldGraph = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Simulation"):WaitForChild("WorldGraph"))
local SpatialHierarchy = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Simulation"):WaitForChild("SpatialHierarchy"))
local CollisionPipeline = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Simulation"):WaitForChild("CollisionPipeline"))
local RewindBuffer = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Simulation"):WaitForChild("RewindBuffer"))
local LockstepBuffer = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Simulation"):WaitForChild("LockstepBuffer"))
local DevTools = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Simulation"):WaitForChild("DevTools"))
local ContentValidator = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Simulation"):WaitForChild("ContentValidator"))

local RuntimeEntrypoint = {}

local _started = false
local _heartbeatConnection = nil
local _lifecycleToken = 0
local _lastReplayCertificate = nil

local function resolveSubsystem(name)
    for _, data in ipairs(Registry:GetOrdered()) do
        if data.name == name then
            return data.instance
        end
    end
    return nil
end

local function resolveWorld(self)
    local simulation = self._kernel and self._kernel.Simulation
    return simulation and simulation.World or nil
end

local function buildBootstrapFromCore()
    local helixRoot = script.Parent.Parent
    local coreFolder = helixRoot:WaitForChild("Core")

    local HelixConfig = require(coreFolder:WaitForChild("HelixConfig"))
    local TimeAuthority = require(coreFolder:WaitForChild("Authorities"):WaitForChild("TimeAuthority"))
    local EventAuthority = require(coreFolder:WaitForChild("Authorities"):WaitForChild("EventAuthority"))
    local GameplayAuthority = require(coreFolder:WaitForChild("Authorities"):WaitForChild("GameplayAuthority"))
    local DomainSchemaAuthority = require(coreFolder:WaitForChild("Authorities"):WaitForChild("DomainSchemaAuthority"))
    local ReplayCertificationAuthority = require(coreFolder:WaitForChild("Authorities"):WaitForChild("ReplayCertificationAuthority"))
    local NetworkingAuthority = require(coreFolder:WaitForChild("Authorities"):WaitForChild("NetworkingAuthority"))
    local ProfilerAuthority = require(coreFolder:WaitForChild("Authorities"):WaitForChild("ProfilerAuthority"))

    HelixConfig:Initialize()
    HelixConfig:Lock()

    return {
        Kernel = {
            Config = HelixConfig,
            TimeAuthority = TimeAuthority,
            EventAuthority = EventAuthority,
            GameplayAuthority = GameplayAuthority,
            DomainSchemaAuthority = DomainSchemaAuthority,
            ReplayCertificationAuthority = ReplayCertificationAuthority,
            NetworkingAuthority = NetworkingAuthority,
            ProfilerAuthority = ProfilerAuthority,
        },
        RuntimeFolder = helixRoot:WaitForChild("Runtime"),
    }
end

local function createSimulationState()
    return {
        World = WorldGraph.new(),
        Spatial = SpatialHierarchy,
        Collision = CollisionPipeline,
        Rewind = RewindBuffer.new(600),
        Lockstep = LockstepBuffer.new(2),
        DevTools = DevTools.new(),
        Pause = false,
        TimeScale = 1,
        LastCollisions = {},
        LastBroadphase = { ProxyCount = 0, PairCount = 0, TestCount = 0 },
        LastConstraintsSolved = 0,
        LastStateDiff = nil,
        LastLockstepInputs = {},
        LastStateHash = "0",
        LastPhysicsTick = 0,
        LastOverlay = nil,
    }
end

local function ensureCoreAuthorities(kernel)
    local coreFolder = script.Parent.Parent:WaitForChild("Core")
    local authorities = coreFolder:WaitForChild("Authorities")

    if not kernel.GameplayAuthority then
        kernel.GameplayAuthority = require(authorities:WaitForChild("GameplayAuthority"))
    end
    if not kernel.DomainSchemaAuthority then
        kernel.DomainSchemaAuthority = require(authorities:WaitForChild("DomainSchemaAuthority"))
    end
    if not kernel.ReplayCertificationAuthority then
        kernel.ReplayCertificationAuthority = require(authorities:WaitForChild("ReplayCertificationAuthority"))
    end
    if not kernel.NetworkingAuthority then
        kernel.NetworkingAuthority = require(authorities:WaitForChild("NetworkingAuthority"))
    end
    if not kernel.ProfilerAuthority then
        kernel.ProfilerAuthority = require(authorities:WaitForChild("ProfilerAuthority"))
    end
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
        error("[RuntimeEntrypoint] Start called while runtime is already running. Call Stop() first.")
    end

    local bootstrap = resolveBootstrap()

    local kernel = bootstrap.Kernel
    local runtimeFolder = bootstrap.RuntimeFolder

    assert(kernel, "[RuntimeEntrypoint] Bootstrap missing Kernel")
    assert(runtimeFolder, "[RuntimeEntrypoint] Bootstrap missing RuntimeFolder")
    assert(kernel.Config, "[RuntimeEntrypoint] Kernel missing Config")
    assert(kernel.TimeAuthority, "[RuntimeEntrypoint] Kernel missing TimeAuthority")
    assert(kernel.EventAuthority, "[RuntimeEntrypoint] Kernel missing EventAuthority")

    ensureCoreAuthorities(kernel)
    assert(kernel.GameplayAuthority, "[RuntimeEntrypoint] Kernel missing GameplayAuthority")
    assert(kernel.DomainSchemaAuthority, "[RuntimeEntrypoint] Kernel missing DomainSchemaAuthority")
    assert(kernel.ReplayCertificationAuthority, "[RuntimeEntrypoint] Kernel missing ReplayCertificationAuthority")
    assert(kernel.NetworkingAuthority, "[RuntimeEntrypoint] Kernel missing NetworkingAuthority")
    assert(kernel.ProfilerAuthority, "[RuntimeEntrypoint] Kernel missing ProfilerAuthority")

    if kernel.Simulation == nil then
        kernel.Simulation = createSimulationState()
    end

    local hostId = game.JobId
    if not hostId or hostId == "" then
        hostId = "studio-server"
    end
    HostAdapterUtils.SetHostId(hostId)

    if kernel.Config and kernel.Config.Get then
        HostAdapterUtils.ConfigureReplay({
            Enabled = kernel.Config:Get("ReplayCaptureEnabled") ~= false,
            MaxEntries = kernel.Config:Get("ReplayCaptureMaxEntries"),
        })
    end

    kernel.DomainSchemaAuthority:Initialize()
    kernel.EventAuthority:Initialize(kernel.DomainSchemaAuthority)
    kernel.GameplayAuthority:Initialize(kernel, kernel.DomainSchemaAuthority)
    kernel.ReplayCertificationAuthority:Initialize()
    kernel.NetworkingAuthority:Initialize()
    kernel.NetworkingAuthority:Configure({
        MaxFutureTicks = kernel.Config:Get("NetworkingMaxFutureTicks"),
        MaxPastTicks = kernel.Config:Get("NetworkingMaxPastTicks"),
        MaxInputsPerTick = kernel.Config:Get("NetworkingMaxInputsPerTick"),
        MaxInputsPerPlayerPerTick = kernel.Config:Get("NetworkingMaxInputsPerPlayerPerTick"),
        MaxRecentRejects = kernel.Config:Get("NetworkingMaxRecentRejects"),
    })
    kernel.ProfilerAuthority:Initialize()
    kernel.ReplayCertificationAuthority:BeginScenario("runtime-session")

    RuntimeHost:Start(runtimeFolder, kernel)
    Scheduler:Start()

    _lifecycleToken += 1
    local activeToken = _lifecycleToken

    _heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        if activeToken ~= _lifecycleToken then
            return
        end
        Scheduler:Update(dt)

        local simulation = kernel.Simulation
        local replayCert = kernel.ReplayCertificationAuthority
        local tick = kernel.TimeAuthority:GetTickIndex()
        local networkingAuthority = kernel.NetworkingAuthority
        if networkingAuthority and networkingAuthority.SetServerTick then
            networkingAuthority:SetServerTick(tick)
        end

        if replayCert and replayCert.RecordTick and simulation then
            replayCert:RecordTick(tick, simulation.LastStateHash)
        end
        if networkingAuthority and networkingAuthority.RecordAuthoritativeFrame and simulation then
            local inputCount = #(simulation.LastLockstepInputs or {})
            networkingAuthority:RecordAuthoritativeFrame(tick, simulation.LastStateHash, inputCount)
        end
    end)

    self._kernel = kernel
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
    _lifecycleToken += 1

    local kernel = self._kernel
    if kernel then
        if kernel.GameplayAuthority and kernel.GameplayAuthority.Shutdown then
            kernel.GameplayAuthority:Shutdown()
        end
        if kernel.EventAuthority and kernel.EventAuthority.Shutdown then
            kernel.EventAuthority:Shutdown()
        end
        if kernel.ReplayCertificationAuthority and kernel.ReplayCertificationAuthority.Reset then
            _lastReplayCertificate = kernel.ReplayCertificationAuthority:EndScenario()
            kernel.ReplayCertificationAuthority:Reset()
        end
        if kernel.NetworkingAuthority and kernel.NetworkingAuthority.Shutdown then
            kernel.NetworkingAuthority:Shutdown()
        end
        if kernel.ProfilerAuthority and kernel.ProfilerAuthority.Shutdown then
            kernel.ProfilerAuthority:Shutdown()
        end
        kernel.Simulation = nil
        if Scheduler.Reset then
            Scheduler:Reset()
        end
    end

    self._kernel = nil
    _started = false
end

function RuntimeEntrypoint:SetSubsystemControlSource(source)
    local changed = 0
    for _, data in ipairs(Registry:GetOrdered()) do
        local subsystem = data.instance
        if subsystem and subsystem.SetControlSource then
            subsystem:SetControlSource(source)
            changed += 1
        end
    end
    print(string.format("[RuntimeEntrypoint] Subsystem control source set to %s (changed=%d)", tostring(source), changed))
    return changed
end

function RuntimeEntrypoint:SetSubsystemControlSourceByName(subsystemName, source)
    local subsystem = resolveSubsystem(subsystemName)
    if not subsystem or not subsystem.SetControlSource then
        return false
    end
    subsystem:SetControlSource(source)
    print(string.format("[RuntimeEntrypoint] %s control source set to %s", tostring(subsystemName), tostring(source)))
    return true
end

function RuntimeEntrypoint:GetSubsystemControlSourceByName(subsystemName)
    local subsystem = resolveSubsystem(subsystemName)
    if not subsystem or not subsystem.GetControlSource then
        return nil
    end
    return subsystem:GetControlSource()
end

function RuntimeEntrypoint:GetSubsystemControlSources()
    local out = {}
    for _, data in ipairs(Registry:GetOrdered()) do
        local subsystem = data.instance
        if subsystem and subsystem.GetControlSource then
            out[data.name] = subsystem:GetControlSource()
        else
            out[data.name] = nil
        end
    end
    return out
end

function RuntimeEntrypoint:SetCameraControlSource(source)
    local cameraSubsystem = resolveSubsystem("CameraSubsystem")
    if not cameraSubsystem or not cameraSubsystem.SetControlSource then
        return false
    end

    cameraSubsystem:SetControlSource(source)
    return true
end

function RuntimeEntrypoint:GetCameraControlSource()
    local cameraSubsystem = resolveSubsystem("CameraSubsystem")
    if not cameraSubsystem or not cameraSubsystem.GetControlSource then
        return nil
    end

    return cameraSubsystem:GetControlSource()
end

function RuntimeEntrypoint:SetAudioBusLevel(busName, level)
    local audioSubsystem = resolveSubsystem("AudioSubsystem")
    if not audioSubsystem or not audioSubsystem.SetBusLevel then
        return false
    end
    return audioSubsystem:SetBusLevel(busName, level)
end

function RuntimeEntrypoint:SetAudioMuted(value)
    local audioSubsystem = resolveSubsystem("AudioSubsystem")
    if not audioSubsystem or not audioSubsystem.SetMuted then
        return false
    end
    audioSubsystem:SetMuted(value == true)
    return true
end

function RuntimeEntrypoint:SetAudioAmbientReverb(reverbName)
    local audioSubsystem = resolveSubsystem("AudioSubsystem")
    if not audioSubsystem or not audioSubsystem.SetAmbientReverb then
        return false
    end
    return audioSubsystem:SetAmbientReverb(reverbName)
end

function RuntimeEntrypoint:CreateEntity(initial)
    local world = resolveWorld(self)
    if not world then
        return nil
    end
    local sanitized = ContentValidator:SanitizeEntityInitial(initial) or initial
    return world:CreateEntity(sanitized)
end

function RuntimeEntrypoint:DestroyEntity(entityId)
    local world = resolveWorld(self)
    if not world then
        return false
    end
    return world:DestroyEntity(entityId)
end

function RuntimeEntrypoint:SetEntityComponent(entityId, componentName, value)
    local world = resolveWorld(self)
    if not world then
        return false
    end
    local sanitized = ContentValidator:SanitizeComponent(componentName, value)
    if sanitized == nil and (componentName == "Body" or componentName == "Bounds" or componentName == "Constraint") then
        return false
    end
    return world:SetComponent(entityId, componentName, sanitized)
end

function RuntimeEntrypoint:SetEntityParent(entityId, parentId)
    local world = resolveWorld(self)
    if not world then
        return false
    end
    return world:SetParent(entityId, parentId)
end

function RuntimeEntrypoint:SetEntityLocalTransform(entityId, x, y, z)
    local world = resolveWorld(self)
    if not world then
        return false
    end
    return world:SetLocalTransform(entityId, x, y, z)
end

function RuntimeEntrypoint:SetEntityVelocity(entityId, vx, vy, vz)
    local world = resolveWorld(self)
    if not world then
        return false
    end

    local body = world:GetComponent(entityId, "Body")
    if type(body) ~= "table" then
        body = { Dynamic = true }
        world:SetComponent(entityId, "Body", body)
    end

    body.VX = tonumber(vx) or 0
    body.VY = tonumber(vy) or 0
    body.VZ = tonumber(vz) or 0
    return true
end

function RuntimeEntrypoint:ApplyEntityForce(entityId, fx, fy, fz)
    local world = resolveWorld(self)
    if not world then
        return false
    end

    local body = world:GetComponent(entityId, "Body")
    if type(body) ~= "table" then
        body = { Dynamic = true }
        world:SetComponent(entityId, "Body", body)
    end

    local force = body.Force
    if type(force) ~= "table" then
        force = { X = 0, Y = 0, Z = 0 }
        body.Force = force
    end

    force.X = (tonumber(force.X) or 0) + (tonumber(fx) or 0)
    force.Y = (tonumber(force.Y) or 0) + (tonumber(fy) or 0)
    force.Z = (tonumber(force.Z) or 0) + (tonumber(fz) or 0)
    return true
end

function RuntimeEntrypoint:BindEntityToInstance(entityId, instance)
    local transformSubsystem = resolveSubsystem("TransformSubsystem")
    if not transformSubsystem or not transformSubsystem.Writer or not transformSubsystem.Writer.Enqueue then
        return false
    end

    transformSubsystem.Writer:Enqueue("BindEntityInstance", {
        EntityId = entityId,
        Instance = instance,
    })
    return true
end

function RuntimeEntrypoint:UnbindEntityFromInstance(entityId)
    local transformSubsystem = resolveSubsystem("TransformSubsystem")
    if not transformSubsystem or not transformSubsystem.Writer or not transformSubsystem.Writer.Enqueue then
        return false
    end

    transformSubsystem.Writer:Enqueue("UnbindEntityInstance", {
        EntityId = entityId,
    })
    return true
end

function RuntimeEntrypoint:SetSimulationPaused(value)
    local simulationControl = resolveSubsystem("SimulationControlSubsystem")
    if not simulationControl or not simulationControl.SetPaused then
        return false
    end
    simulationControl:SetPaused(value == true)
    return true
end

function RuntimeEntrypoint:RequestSimulationRewind(targetTick)
    local simulationControl = resolveSubsystem("SimulationControlSubsystem")
    if not simulationControl or not simulationControl.RequestRewind then
        return false
    end
    return simulationControl:RequestRewind(targetTick)
end

function RuntimeEntrypoint:ResetSimulationState()
    local kernel = self._kernel
    if not kernel then
        return false
    end

    kernel.Simulation = createSimulationState()
    return true
end

function RuntimeEntrypoint:QueueLockstepInput(playerId, input)
    local timeAuthority = self._kernel and self._kernel.TimeAuthority
    local gameplayAuthority = self._kernel and self._kernel.GameplayAuthority
    if not gameplayAuthority or not gameplayAuthority.QueueInput or not timeAuthority or not timeAuthority.GetTickIndex then
        return false
    end

    return gameplayAuthority:QueueInput(playerId, timeAuthority:GetTickIndex(), input)
end

function RuntimeEntrypoint:QueueAuthoritativeInput(playerId, sequence, input, targetTick)
    local networkingAuthority = self._kernel and self._kernel.NetworkingAuthority
    local timeAuthority = self._kernel and self._kernel.TimeAuthority
    local config = self._kernel and self._kernel.Config
    if config and config.Get and config:Get("AuthoritativeNetworkingEnabled") == false then
        return false, "authoritative_networking_disabled"
    end
    if not networkingAuthority or not networkingAuthority.QueueClientInput or not timeAuthority or not timeAuthority.GetTickIndex then
        return false, "unavailable"
    end

    local tick = targetTick
    if type(tick) ~= "number" then
        tick = timeAuthority:GetTickIndex()
    end
    return networkingAuthority:QueueClientInput(playerId, tick, sequence, input)
end

function RuntimeEntrypoint:ReconcileStateHash(tick, remoteHash)
    local simulation = self._kernel and self._kernel.Simulation
    local lockstep = simulation and simulation.Lockstep
    if not lockstep then
        return false
    end
    return lockstep:ReconcileStateHash(tick, remoteHash)
end

function RuntimeEntrypoint:RegisterGameplaySystem(name, handler, priority)
    local gameplayAuthority = self._kernel and self._kernel.GameplayAuthority
    if not gameplayAuthority or not gameplayAuthority.RegisterSystem then
        return false
    end
    gameplayAuthority:RegisterSystem(name, handler, priority)
    return true
end

function RuntimeEntrypoint:GetGameplayFrameStats()
    local gameplayAuthority = self._kernel and self._kernel.GameplayAuthority
    if not gameplayAuthority or not gameplayAuthority.GetLastFrameStats then
        return nil
    end
    return gameplayAuthority:GetLastFrameStats()
end

function RuntimeEntrypoint:GetAuthoritativeNetworkingFrame()
    local networkingAuthority = self._kernel and self._kernel.NetworkingAuthority
    if not networkingAuthority or not networkingAuthority.GetLastFrame then
        return nil
    end
    return networkingAuthority:GetLastFrame()
end

function RuntimeEntrypoint:GetAuthoritativeRejects()
    local networkingAuthority = self._kernel and self._kernel.NetworkingAuthority
    if not networkingAuthority or not networkingAuthority.GetRecentRejects then
        return nil
    end
    return networkingAuthority:GetRecentRejects()
end

function RuntimeEntrypoint:GetAuthoritativePlayerState(playerId)
    local networkingAuthority = self._kernel and self._kernel.NetworkingAuthority
    if not networkingAuthority or not networkingAuthority.GetPlayerState then
        return nil
    end
    return networkingAuthority:GetPlayerState(playerId)
end

function RuntimeEntrypoint:RegisterDomainSchema(domain, shape)
    local schema = self._kernel and self._kernel.DomainSchemaAuthority
    if not schema or not schema.RegisterSchema then
        return false
    end
    return schema:RegisterSchema(domain, shape)
end

function RuntimeEntrypoint:BeginReplayCertification(scenarioId)
    local cert = self._kernel and self._kernel.ReplayCertificationAuthority
    if not cert or not cert.BeginScenario then
        return false
    end
    return cert:BeginScenario(scenarioId)
end

function RuntimeEntrypoint:EndReplayCertification()
    local cert = self._kernel and self._kernel.ReplayCertificationAuthority
    if not cert or not cert.EndScenario then
        return nil
    end
    return cert:EndScenario()
end

function RuntimeEntrypoint:CertifyReplayAgainstBaseline(certificate)
    local cert = self._kernel and self._kernel.ReplayCertificationAuthority
    if not cert or not cert.CertifyAgainstBaseline then
        return false, "unavailable"
    end
    return cert:CertifyAgainstBaseline(certificate)
end

function RuntimeEntrypoint:GetLastReplayCertificate()
    return _lastReplayCertificate
end

function RuntimeEntrypoint:GetDebugOverlay()
    local simulation = self._kernel and self._kernel.Simulation
    if not simulation then
        return nil
    end
    return simulation.LastOverlay
end

function RuntimeEntrypoint:GetDeterministicStateDiff()
    local simulation = self._kernel and self._kernel.Simulation
    if not simulation then
        return nil
    end
    return simulation.LastStateDiff
end

function RuntimeEntrypoint:GetProfilerFrame()
    local profiler = self._kernel and self._kernel.ProfilerAuthority
    if not profiler or not profiler.GetLastFrame then
        return nil
    end
    return profiler:GetLastFrame()
end

function RuntimeEntrypoint:GetDebugInspectorData()
    local simulation = self._kernel and self._kernel.Simulation
    local profiler = self._kernel and self._kernel.ProfilerAuthority
    local networking = self._kernel and self._kernel.NetworkingAuthority

    local overlay = simulation and simulation.LastOverlay or nil
    local diff = simulation and simulation.LastStateDiff or nil
    local profilerFrame = profiler and profiler.GetLastFrame and profiler:GetLastFrame() or nil
    local netFrame = networking and networking.GetLastFrame and networking:GetLastFrame() or nil
    local rejects = networking and networking.GetRecentRejects and networking:GetRecentRejects() or {}

    return {
        Overlay = overlay,
        Diff = diff,
        Profiler = profilerFrame,
        Networking = netFrame,
        Rejects = rejects,
    }
end

function RuntimeEntrypoint:RunSimulationStressTest(options)
    local kernel = self._kernel
    if not kernel or not kernel.Simulation then
        return nil
    end

    local simulation = kernel.Simulation
    local world = simulation.World
    local pipeline = simulation.PhysicsPipeline
    if not world or not pipeline then
        return nil
    end

    local opts = type(options) == "table" and options or {}
    local entityCount = math.max(1, math.floor(tonumber(opts.EntityCount) or 200))
    local steps = math.max(1, math.floor(tonumber(opts.Steps) or 120))
    local radius = tonumber(opts.SpawnRadius) or 50
    local amplitude = tonumber(opts.Amplitude) or 25
    local startTime = os.clock()

    local created = {}
    for index = 1, entityCount do
        local angle = (index / entityCount) * math.pi * 2
        local id = world:CreateEntity({
            LocalTransform = {
                X = math.cos(angle) * radius,
                Y = 40 + (index % 7),
                Z = math.sin(angle) * radius,
            },
            Components = {
                Bounds = { Radius = 1 + (index % 3) * 0.15 },
                Body = {
                    Dynamic = true,
                    Mass = 1 + (index % 5) * 0.3,
                    VX = math.sin(index) * amplitude * 0.05,
                    VY = 0,
                    VZ = math.cos(index) * amplitude * 0.05,
                    LinearDamping = 0.01,
                    Restitution = 0.05,
                    Friction = 0.2,
                },
            },
        })
        created[#created + 1] = id
    end

    local maxCollisions = 0
    local maxPairs = 0
    local maxDiffChanged = 0
    local totalCollisions = 0

    for _ = 1, steps do
        local result = pipeline:Step(simulation, pipeline.Config.FixedStep, kernel)
        if result then
            local c = result.CollisionCount or 0
            totalCollisions += c
            if c > maxCollisions then
                maxCollisions = c
            end
            local pairs = result.Broadphase and result.Broadphase.PairCount or 0
            if pairs > maxPairs then
                maxPairs = pairs
            end
            local changed = result.StateDiff and result.StateDiff.ChangedCount or 0
            if changed > maxDiffChanged then
                maxDiffChanged = changed
            end
        end
    end

    for index = 1, #created do
        world:DestroyEntity(created[index])
    end

    local durationMs = (os.clock() - startTime) * 1000
    local stats = collectgarbage("count")

    return {
        EntityCount = entityCount,
        Steps = steps,
        DurationMs = durationMs,
        AvgStepMs = durationMs / steps,
        MaxCollisions = maxCollisions,
        AvgCollisions = totalCollisions / steps,
        MaxBroadphasePairs = maxPairs,
        MaxDiffChanged = maxDiffChanged,
        LuaMemoryKB = stats,
    }
end

function RuntimeEntrypoint:SetDebugOverlayEnabled(value)
    local simulation = self._kernel and self._kernel.Simulation
    local devTools = simulation and simulation.DevTools
    if not devTools or not devTools.SetOverlayEnabled then
        return false
    end
    devTools:SetOverlayEnabled(value == true)
    return true
end

function RuntimeEntrypoint:SetInspectorEntity(entityId)
    local simulation = self._kernel and self._kernel.Simulation
    local devTools = simulation and simulation.DevTools
    if not devTools or not devTools.SetInspectorEntity then
        return false
    end
    devTools:SetInspectorEntity(entityId)
    return true
end

return RuntimeEntrypoint
