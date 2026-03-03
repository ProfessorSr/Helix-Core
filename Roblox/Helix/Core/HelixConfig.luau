----------------------------------------------------------------
-- FILE: HelixConfig (Authority Implementation)
----------------------------------------------------------------

local HelixConfig = {}

-- Symbolic defaults (no magic numbers)
HelixConfig.DefaultTickRate = 30
HelixConfig.DefaultSeed = 0

-- Internal state
local _locked = false

local _defaults = {
    TickRate = HelixConfig.DefaultTickRate,
    MaxTickRate = 240,
    MinTickRate = 15,
    MaxTicksPerFrame = 3,
    FailOnMissingCapability = true,
    DebugLogging = true,
    Seed = HelixConfig.DefaultSeed,
    ReplayCaptureEnabled = true,
    ReplayCaptureMaxEntries = 4096,
    CameraControlSource = "Host",
    InputControlSource = "Helix",
    AudioControlSource = "Helix",
    DefaultSubsystemControlSource = "Helix",
    AnimationControlSource = "Helix",
    EventControlSource = "Helix",
    NetworkingControlSource = "Helix",
    PhysicsControlSource = "Helix",
    PhysicsFixedStep = 1 / 60,
    PhysicsMaxSubsteps = 4,
    PhysicsMaxFrameTime = 1 / 10,
    PhysicsGravity = 196.2,
    PhysicsRewindCaptureInterval = 1,
    PhysicsConstraintIterations = 4,
    PhysicsCollisionIterations = 2,
    PhysicsMaxCollisionRecordsPerStep = 512,
    PhysicsCaptureStateDiff = true,
    PhysicsMaxSpeed = 2048,
    PhysicsPenetrationSlop = 0.001,
    PhysicsBaumgarte = 0.25,
    PhysicsMaxCorrection = 1.0,
    PhysicsSleepVelocity = 0.01,
    PhysicsSleepFrames = 30,
    TimeControlSource = "Helix",
    TransformControlSource = "Helix",
    HostPhysicsNeutralizationPolicy = "AnchorNoCollide",
    WorldControlSource = "Helix",
    AccountControlSource = "Helix",
    PersistenceControlSource = "Helix",
    PolicyControlSource = "Helix",
    SecurityControlSource = "Helix",
    TelemetryControlSource = "Helix",
    AssetControlSource = "Helix",
    ComponentControlSource = "Helix",
    ReplicationControlSource = "Helix",
    ScriptingControlSource = "Helix",
    StateSyncControlSource = "Helix",
    UIControlSource = "Helix",
    SimulationControlSource = "Helix",
    StepDebuggerControlSource = "Helix",
    TimeScaleControlSource = "Helix",
    ProfilingEnabled = true,
    AuthoritativeNetworkingEnabled = true,
    NetworkingMaxFutureTicks = 3,
    NetworkingMaxPastTicks = 6,
    NetworkingMaxInputsPerTick = 512,
    NetworkingMaxInputsPerPlayerPerTick = 16,
    NetworkingMaxRecentRejects = 128,
}

local _config = {}

local function sortedKeys(source)
    local keys = {}
    for key in pairs(source) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

-- Deep copy defaults
local function copyDefaults()
    for k, v in pairs(_defaults) do
        _config[k] = v
    end
end

-- Merge override table (only known keys)
local function mergeOverride(override)
    for k, v in pairs(override) do
        if _defaults[k] ~= nil then
            _config[k] = v
        end
    end
end

function HelixConfig:Initialize(overrideTable)
    if _locked then
        return
    end

    copyDefaults()

    if type(overrideTable) == "table" then
        mergeOverride(overrideTable)
    end

    -- Clamp TickRate within allowed bounds
    if _config.TickRate < _config.MinTickRate then
        _config.TickRate = _config.MinTickRate
    elseif _config.TickRate > _config.MaxTickRate then
        _config.TickRate = _config.MaxTickRate
    end

    print("[Helix] Final Configuration:")
    for _, k in ipairs(sortedKeys(_config)) do
        local v = _config[k]
        print("   ", k, "=", v)
    end
end

function HelixConfig:Get(key)
    return _config[key]
end

function HelixConfig:GetAll()
    local snapshot = {}
    for key, value in pairs(_config) do
        snapshot[key] = value
    end
    return snapshot
end

function HelixConfig:Set(key, value)
    if _locked then
        warn("[HelixConfig] Attempt to modify locked config:", key)
        return
    end

    if _defaults[key] ~= nil then
        _config[key] = value
    end
end

function HelixConfig:Lock()
    _locked = true
end

function HelixConfig:IsLocked()
    return _locked
end

function HelixConfig:GetFixedStep()
    return 1 / _config.TickRate
end

function HelixConfig:GetSeed()
    return _config.Seed
end

function HelixConfig:SetSeed(value)
    if _locked then
        warn("[HelixConfig] Attempt to modify locked Seed")
        return
    end
    _config.Seed = value
end

return HelixConfig
