----------------------------------------------------------------
-- FILE: TimeSubsystem
----------------------------------------------------------------

local TimeSubsystem = {}

function TimeSubsystem:Initialize()
    print("[TimeSubsystem] Initialized")
end

function TimeSubsystem:Tick()
    -- Deterministic fixed-step logic here
end

function TimeSubsystem:Shutdown()
    print("[TimeSubsystem] Shutdown")
end

return TimeSubsystem
