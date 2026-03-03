----------------------------------------------------------------
-- FILE: PhysicsSubsystem
----------------------------------------------------------------

local PhysicsSubsystem = {}

function PhysicsSubsystem:Initialize()
    print("[PhysicsSubsystem] Initialized")
end

function PhysicsSubsystem:Tick()
    -- Deterministic fixed-step logic here
end

function PhysicsSubsystem:Shutdown()
    print("[PhysicsSubsystem] Shutdown")
end

return PhysicsSubsystem
