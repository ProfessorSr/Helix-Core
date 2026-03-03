----------------------------------------------------------------
-- FILE: ClimateSubsystem
----------------------------------------------------------------

local ClimateSubsystem = {}

function ClimateSubsystem:Initialize()
    print("[ClimateSubsystem] Initialized")
end

function ClimateSubsystem:Tick()
    -- Deterministic fixed-step logic here
end

function ClimateSubsystem:Shutdown()
    print("[ClimateSubsystem] Shutdown")
end

return ClimateSubsystem
