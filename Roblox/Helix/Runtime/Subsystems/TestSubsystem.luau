----------------------------------------------------------------
-- FILE: TestSubsystem
----------------------------------------------------------------

local TestSubsystem = {}

local TimeAuthority = require(script.Parent.Parent.Parent.Core.Authorities.TimeAuthority)

function TestSubsystem:Initialize()
    print("[TestSubsystem] Initialized")
end

function TestSubsystem:Tick()
    local tick = TimeAuthority:GetTickIndex()
    local tps = TimeAuthority:GetTicksPerSecond()

    if tick % tps == 0 then
        print("[TestSubsystem] 1 second elapsed at " .. tps .. "Hz")
    end
end

function TestSubsystem:Shutdown()
    print("[TestSubsystem] Shutdown")
end

return TestSubsystem