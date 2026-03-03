----------------------------------------------------------------
-- FILE: LightingSubsystem
----------------------------------------------------------------

local LightingSubsystem = {}

function LightingSubsystem:Initialize()
    print("[LightingSubsystem] Initialized")
end

function LightingSubsystem:Tick()
    -- Deterministic fixed-step logic here
end

function LightingSubsystem:Shutdown()
    print("[LightingSubsystem] Shutdown")
end

return LightingSubsystem
