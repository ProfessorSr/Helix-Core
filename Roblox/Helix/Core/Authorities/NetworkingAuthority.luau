local NetworkingAuthority = {}

local _initialized = false
local _inputsByTick = {}
local _playerState = {}
local _serverTick = 0
local _recentRejects = {}
local _maxRecentRejects = 128
local _maxInputsPerTick = 512
local _maxInputsPerPlayerPerTick = 16
local _maxFutureTicks = 3
local _maxPastTicks = 6
local _lastFrame = {
    Tick = 0,
    InputCount = 0,
    LastStateHash = "0",
    RejectCount = 0,
    LastRejectReason = nil,
}

local function pushReject(playerId, tick, sequence, reason)
    _recentRejects[#_recentRejects + 1] = {
        PlayerId = tostring(playerId or "unknown"),
        Tick = math.floor(tonumber(tick) or 0),
        Sequence = math.floor(tonumber(sequence) or 0),
        Reason = reason,
    }
    while #_recentRejects > _maxRecentRejects do
        table.remove(_recentRejects, 1)
    end
    _lastFrame.RejectCount = (_lastFrame.RejectCount or 0) + 1
    _lastFrame.LastRejectReason = reason
end

local function getOrCreatePlayerState(playerKey)
    local state = _playerState[playerKey]
    if state then
        return state
    end

    state = {
        LastSequence = nil,
        LastAcceptedTick = nil,
        AcceptedInputs = 0,
        RejectedInputs = 0,
    }
    _playerState[playerKey] = state
    return state
end

local function bucketSize(bucket)
    local count = 0
    for _ = 1, #bucket do
        count += 1
    end
    return count
end

local function playerInputsInBucket(bucket, playerKey)
    local count = 0
    for index = 1, #bucket do
        if bucket[index].PlayerId == playerKey then
            count += 1
        end
    end
    return count
end

function NetworkingAuthority:Initialize()
    _initialized = true
    _inputsByTick = {}
    _playerState = {}
    _serverTick = 0
    _recentRejects = {}
    _lastFrame = {
        Tick = 0,
        InputCount = 0,
        LastStateHash = "0",
        RejectCount = 0,
        LastRejectReason = nil,
    }
end

function NetworkingAuthority:SetServerTick(tick)
    _serverTick = math.floor(tonumber(tick) or 0)

    local minTick = _serverTick - _maxPastTicks
    local maxTick = _serverTick + _maxFutureTicks
    for bucketTick in pairs(_inputsByTick) do
        if bucketTick < minTick or bucketTick > maxTick then
            _inputsByTick[bucketTick] = nil
        end
    end
end

function NetworkingAuthority:Configure(config)
    if type(config) ~= "table" then
        return
    end

    if type(config.MaxRecentRejects) == "number" and config.MaxRecentRejects >= 1 then
        _maxRecentRejects = math.floor(config.MaxRecentRejects)
    end
    if type(config.MaxInputsPerTick) == "number" and config.MaxInputsPerTick >= 1 then
        _maxInputsPerTick = math.floor(config.MaxInputsPerTick)
    end
    if type(config.MaxInputsPerPlayerPerTick) == "number" and config.MaxInputsPerPlayerPerTick >= 1 then
        _maxInputsPerPlayerPerTick = math.floor(config.MaxInputsPerPlayerPerTick)
    end
    if type(config.MaxFutureTicks) == "number" and config.MaxFutureTicks >= 0 then
        _maxFutureTicks = math.floor(config.MaxFutureTicks)
    end
    if type(config.MaxPastTicks) == "number" and config.MaxPastTicks >= 0 then
        _maxPastTicks = math.floor(config.MaxPastTicks)
    end
end

function NetworkingAuthority:QueueClientInput(playerId, tick, sequence, input)
    if not _initialized then
        return false, "not_initialized"
    end
    if type(tick) ~= "number" then
        return false, "invalid_tick"
    end

    local playerKey = tostring(playerId or "unknown")
    local seq = math.floor(tonumber(sequence) or 0)
    local state = getOrCreatePlayerState(playerKey)
    if state.LastSequence ~= nil and seq <= state.LastSequence then
        state.RejectedInputs += 1
        pushReject(playerKey, tick, seq, "stale_sequence")
        return false, "stale_sequence"
    end

    local integerTick = math.floor(tick)
    if integerTick > (_serverTick + _maxFutureTicks) then
        state.RejectedInputs += 1
        pushReject(playerKey, integerTick, seq, "too_far_future")
        return false, "too_far_future"
    end
    if integerTick < (_serverTick - _maxPastTicks) then
        state.RejectedInputs += 1
        pushReject(playerKey, integerTick, seq, "too_far_past")
        return false, "too_far_past"
    end
    if type(input) ~= "table" then
        state.RejectedInputs += 1
        pushReject(playerKey, integerTick, seq, "invalid_input")
        return false, "invalid_input"
    end

    local bucket = _inputsByTick[integerTick]
    if not bucket then
        bucket = {}
        _inputsByTick[integerTick] = bucket
    end

    if bucketSize(bucket) >= _maxInputsPerTick then
        state.RejectedInputs += 1
        pushReject(playerKey, integerTick, seq, "tick_queue_full")
        return false, "tick_queue_full"
    end
    if playerInputsInBucket(bucket, playerKey) >= _maxInputsPerPlayerPerTick then
        state.RejectedInputs += 1
        pushReject(playerKey, integerTick, seq, "player_tick_queue_full")
        return false, "player_tick_queue_full"
    end

    bucket[#bucket + 1] = {
        PlayerId = playerKey,
        Sequence = seq,
        Input = input or {},
    }
    state.LastSequence = seq
    state.LastAcceptedTick = integerTick
    state.AcceptedInputs += 1

    return true
end

function NetworkingAuthority:ConsumeInputsForTick(tick)
    local integerTick = math.floor(tick or 0)
    local bucket = _inputsByTick[integerTick] or {}
    _inputsByTick[integerTick] = nil

    table.sort(bucket, function(a, b)
        if a.PlayerId ~= b.PlayerId then
            return a.PlayerId < b.PlayerId
        end
        return a.Sequence < b.Sequence
    end)

    return bucket
end

function NetworkingAuthority:RecordAuthoritativeFrame(tick, stateHash, inputCount)
    _lastFrame = {
        Tick = math.floor(tick or 0),
        InputCount = math.floor(inputCount or 0),
        LastStateHash = tostring(stateHash or "0"),
        RejectCount = _lastFrame.RejectCount or 0,
        LastRejectReason = _lastFrame.LastRejectReason,
    }
end

function NetworkingAuthority:GetLastFrame()
    return _lastFrame
end

function NetworkingAuthority:GetRecentRejects()
    local out = {}
    for index = 1, #_recentRejects do
        out[index] = _recentRejects[index]
    end
    return out
end

function NetworkingAuthority:GetPlayerState(playerId)
    local playerKey = tostring(playerId or "unknown")
    return _playerState[playerKey]
end

function NetworkingAuthority:Shutdown()
    _initialized = false
    _inputsByTick = {}
    _playerState = {}
    _serverTick = 0
    _recentRejects = {}
    _lastFrame = {
        Tick = 0,
        InputCount = 0,
        LastStateHash = "0",
        RejectCount = 0,
        LastRejectReason = nil,
    }
end

return NetworkingAuthority
