
----------------------------------------------------------------
-- FILE: Clock
----------------------------------------------------------------

local Clock = {}
Clock._tick = 0

function Clock:Increment()
    self._tick += 1
end

function Clock:GetTick()
    return self._tick
end

return Clock
