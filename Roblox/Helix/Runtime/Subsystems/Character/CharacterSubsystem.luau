----------------------------------------------------------------
-- FILE: CharacterSubsystem
----------------------------------------------------------------

local CharacterSubsystem = {}

function CharacterSubsystem:Initialize()
    print("[CharacterSubsystem] Initialized")
end

function CharacterSubsystem:Tick()
    -- Deterministic fixed-step logic here
end

function CharacterSubsystem:Shutdown()
    print("[CharacterSubsystem] Shutdown")
end

return CharacterSubsystem
