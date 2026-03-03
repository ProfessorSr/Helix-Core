----------------------------------------------------------------
-- FILE: AISubsystem
----------------------------------------------------------------

local AISubsystem = {}

function AISubsystem:Initialize()
    print("[AISubsystem] Initialized")
end

function AISubsystem:Tick()
    -- Deterministic fixed-step logic here
end

function AISubsystem:Shutdown()
    print("[AISubsystem] Shutdown")
end

return AISubsystem
