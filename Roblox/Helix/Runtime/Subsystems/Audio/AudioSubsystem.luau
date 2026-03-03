----------------------------------------------------------------
-- FILE: AudioSubsystem
----------------------------------------------------------------

local AudioSubsystem = {}

function AudioSubsystem:Initialize()
    print("[AudioSubsystem] Initialized")
end

function AudioSubsystem:Tick()
    -- Deterministic fixed-step logic here
end

function AudioSubsystem:Shutdown()
    print("[AudioSubsystem] Shutdown")
end

return AudioSubsystem
