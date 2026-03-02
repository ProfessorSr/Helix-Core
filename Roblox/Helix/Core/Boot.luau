----------------------------------------------------------------
-- FILE: Boot
----------------------------------------------------------------

local Registry = require(script.Parent.Registry)

local Boot = {}

-- Internal state
local _initialized = false
local _registryLocked = false
local _requiredCapabilities = {}
local _hostCapabilities = {}
local _overrideMissing = false

-- =============================================================
-- Capability Registration (Core Expectations)
-- =============================================================

function Boot:RegisterRequiredCapability(name)
    _requiredCapabilities[name] = true
    print(string.format("[Helix] Required Capability Registered: %s", name))
end

function Boot:SetHostCapabilities(capabilityTable)
    _hostCapabilities = capabilityTable or {}

    print("[Helix] Host Capabilities Registered:")
    for name, value in pairs(_hostCapabilities) do
        print(string.format("    %s = %s", name, tostring(value)))
    end
end

function Boot:SetOverrideMissingCapabilities(state)
    _overrideMissing = state == true
end

-- =============================================================
-- Validation
-- =============================================================

local function validateCapabilities()
    for capability, _ in pairs(_requiredCapabilities) do
        if not _hostCapabilities[capability] then
            warn(string.format("[Helix] Missing Capability: %s", capability))

            if not _overrideMissing then
                error(string.format(
                    "[Helix] Boot failed. Missing required capability: %s (override required)",
                    capability
                ))
            end
        end
    end
end

-- =============================================================
-- Initialization
-- =============================================================

function Boot:Initialize()
    if _initialized then
        error("[Helix] Boot already initialized.")
    end

    validateCapabilities()
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
