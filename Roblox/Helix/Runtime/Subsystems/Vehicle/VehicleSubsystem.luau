----------------------------------------------------------------
-- FILE: VehicleSubsystem
----------------------------------------------------------------

local VehicleSubsystem = {}

function VehicleSubsystem:Initialize()
    print("[VehicleSubsystem] Initialized")
end

function VehicleSubsystem:Tick()
    -- Deterministic fixed-step logic here
end

function VehicleSubsystem:Shutdown()
    print("[VehicleSubsystem] Shutdown")
end

return VehicleSubsystem
