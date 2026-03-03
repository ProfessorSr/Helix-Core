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
}

local _config = {}

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
    for k, v in pairs(_config) do
        print("   ", k, "=", v)
    end
end

function HelixConfig:Get(key)
    return _config[key]
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
