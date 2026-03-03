local RewindBuffer = {}
RewindBuffer.__index = RewindBuffer

function RewindBuffer.new(maxFrames)
    return setmetatable({
        MaxFrames = math.max(1, math.floor(maxFrames or 300)),
        Frames = {},
    }, RewindBuffer)
end

function RewindBuffer:Capture(tick, worldState)
    self.Frames[#self.Frames + 1] = {
        Tick = tick,
        State = worldState,
    }

    while #self.Frames > self.MaxFrames do
        table.remove(self.Frames, 1)
    end
end

function RewindBuffer:GetLatest()
    return self.Frames[#self.Frames]
end

function RewindBuffer:RestoreClosest(targetTick)
    local best = nil
    local bestDelta = math.huge
    for index = 1, #self.Frames do
        local frame = self.Frames[index]
        local delta = math.abs((frame.Tick or 0) - targetTick)
        if delta < bestDelta then
            best = frame
            bestDelta = delta
        end
    end
    return best
end

return RewindBuffer
