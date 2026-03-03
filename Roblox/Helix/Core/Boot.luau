----------------------------------------------------------------
-- FILE: Boot
----------------------------------------------------------------

local Registry = require(script.Parent.Registry)

local Boot = {}

-- Internal state
local _initialized = false
local _registryLocked = false
local _requiredCapabilities = {}

-- =============================================================
-- Capability Registration (Core Expectations)
-- =============================================================

function Boot:RegisterRequiredCapability(name)
    _requiredCapabilities[name] = true
    print(string.format("[Helix] Required Capability Registered: %s", name))
end


-- =============================================================
-- Validation
-- =============================================================

local function validateCapabilities(capabilityMap)
    for capability, _ in pairs(_requiredCapabilities) do
        if not capabilityMap or not capabilityMap[capability] then
            error(string.format(
                "[Helix] Boot failed. Missing required capability: %s",
                capability
            ))
        end
    end
end

-- =============================================================
-- Initialization
-- =============================================================

function Boot:Initialize(capabilityMap)
    if _initialized then
        error("[Helix] Boot already initialized.")
    end

    validateCapabilities(capabilityMap)
    print("[Helix] Capability validation successful.")

    Registry:Lock()
    _registryLocked = true
    _initialized = true
end

function Boot:IsInitialized()
    return _initialized
end

function Boot:IsRegistryLocked()
    return _registryLocked
end

return Boot
