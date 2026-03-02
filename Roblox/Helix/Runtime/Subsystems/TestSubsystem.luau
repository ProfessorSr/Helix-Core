
----------------------------------------------------------------
-- FILE: TestSubsystem
----------------------------------------------------------------

local TestSubsystem = {}
local counter = 0

function TestSubsystem:Tick()
    counter += 1
    if counter % 60 == 0 then
        print("[TestSubsystem] 1 second elapsed at 60Hz")
    end
end

return TestSubsystem
