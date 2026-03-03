----------------------------------------------------------------
-- FILE: AnimationSubsystem
----------------------------------------------------------------

local AnimationSubsystem = {}

function AnimationSubsystem:Initialize()
    print("[AnimationSubsystem] Initialized")
end

function AnimationSubsystem:Tick()
    -- Deterministic fixed-step logic here
end

function AnimationSubsystem:Shutdown()
    print("[AnimationSubsystem] Shutdown")
end

return AnimationSubsystem
