local LockstepBuffer = {}
LockstepBuffer.__index = LockstepBuffer

function LockstepBuffer.new(inputDelayTicks)
    return setmetatable({
        InputDelayTicks = math.max(0, math.floor(inputDelayTicks or 2)),
        InputsByTick = {},
        TickHashes = {},
        ReconciliationMismatches = 0,
    }, LockstepBuffer)
end

function LockstepBuffer:QueueInput(playerId, tick, input)
    local scheduledTick = tick + self.InputDelayTicks
    local bucket = self.InputsByTick[scheduledTick]
    if not bucket then
        bucket = {}
        self.InputsByTick[scheduledTick] = bucket
    end

    bucket[#bucket + 1] = {
        PlayerId = playerId,
        Input = input,
    }

    table.sort(bucket, function(a, b)
        return tostring(a.PlayerId) < tostring(b.PlayerId)
    end)
end

function LockstepBuffer:ConsumeTick(tick)
    local bucket = self.InputsByTick[tick] or {}
    self.InputsByTick[tick] = nil
    return bucket
end

function LockstepBuffer:RecordStateHash(tick, hash)
    self.TickHashes[tick] = hash
end

function LockstepBuffer:ReconcileStateHash(tick, remoteHash)
    local localHash = self.TickHashes[tick]
    if localHash and remoteHash and localHash ~= remoteHash then
        self.ReconciliationMismatches += 1
        return false
    end
    return true
end

return LockstepBuffer
