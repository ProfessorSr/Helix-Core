local HostAdapterUtils = {}
local HostReadSchemas = require(script.Parent:WaitForChild("HostReadSchemas"))
local HostCommandSchemas = require(script.Parent:WaitForChild("HostCommandSchemas"))
local DEFAULT_MAX_PENDING_COMMANDS = 256
local SUPPORTED_COMMAND_VERSION = 1
local SUPPORTED_SNAPSHOT_VERSION = 1

local _replayEnabled = true
local _replayMaxEntries = 4096
local _replayCursor = 0
local _replayEntries = {}
local _parityBaseline = {}
local _parityErrors = {}
local _hostId = "roblox-server"

local function clearTable(t)
    for key in pairs(t) do
        t[key] = nil
    end
end

local function toDeterministicString(value)
    local valueType = type(value)
    if valueType == "nil" then
        return "nil"
    end
    if valueType == "boolean" then
        return value and "true" or "false"
    end
    if valueType == "number" then
        return string.format("%.17g", value)
    end
    if valueType == "string" then
        return value
    end
    if valueType == "table" then
        local keys = {}
        for key in pairs(value) do
            table.insert(keys, key)
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)

        local out = {}
        for index = 1, #keys do
            local key = keys[index]
            out[index] = tostring(key) .. "=" .. toDeterministicString(value[key])
        end
        return "{" .. table.concat(out, ";") .. "}"
    end

    return tostring(value)
end

local function hashFNV1a32(text)
    local hash = 2166136261
    for index = 1, #text do
        hash = bit32.bxor(hash, string.byte(text, index))
        hash = (hash * 16777619) % 4294967296
    end
    return string.format("%08x", hash)
end

local function shallowClone(value)
    if type(value) ~= "table" then
        return value
    end

    local clone = {}
    for key, item in pairs(value) do
        clone[key] = item
    end
    return clone
end

local function stableDataDiff(previousData, nextData)
    local prev = type(previousData) == "table" and previousData or {}
    local next = type(nextData) == "table" and nextData or {}

    local keys = {}
    local seen = {}
    for key in pairs(prev) do
        seen[key] = true
        table.insert(keys, key)
    end
    for key in pairs(next) do
        if not seen[key] then
            table.insert(keys, key)
        end
    end

    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    local changed = {}
    for index = 1, #keys do
        local key = keys[index]
        if prev[key] ~= next[key] then
            changed[#changed + 1] = {
                Key = key,
                Old = prev[key],
                New = next[key],
            }
        end
    end

    return changed
end

local function appendReplayEntry(entry)
    if not _replayEnabled then
        return
    end

    _replayCursor += 1
    entry.Index = _replayCursor
    _replayEntries[#_replayEntries + 1] = entry

    if #_replayEntries > _replayMaxEntries then
        table.remove(_replayEntries, 1)
    end
end

local function registerParity(snapshot, signature)
    local tick = snapshot.Tick
    if type(tick) ~= "number" then
        return true
    end

    local parityKey = table.concat({
        tostring(snapshot.Domain),
        tostring(snapshot.Service),
        tostring(tick),
    }, "::")

    local existing = _parityBaseline[parityKey]
    if existing == nil then
        _parityBaseline[parityKey] = {
            HostId = snapshot.HostId,
            Signature = signature,
        }
        return true
    end

    if existing.Signature ~= signature then
        _parityErrors[parityKey] = {
            HostId = existing.HostId,
            Signature = existing.Signature,
            MismatchHostId = snapshot.HostId,
            MismatchSignature = signature,
        }
        return false
    end

    return true
end

function HostAdapterUtils.TryGetService(serviceName)
    local ok, service = pcall(game.GetService, game, serviceName)
    if ok then
        return service
    end
    return nil
end

function HostAdapterUtils.TryReadProperty(instance, propertyName, defaultValue)
    local ok, value = pcall(function()
        return instance[propertyName]
    end)

    if ok then
        return value
    end

    return defaultValue
end

function HostAdapterUtils.TryWriteProperty(instance, propertyName, value)
    local ok = pcall(function()
        instance[propertyName] = value
    end)

    return ok
end

function HostAdapterUtils.NewSnapshot(domain, serviceName, dt)
    return {
        SnapshotVersion = SUPPORTED_SNAPSHOT_VERSION,
        HostId = _hostId,
        Domain = domain,
        Service = serviceName,
        Dt = dt,
        Data = {},
    }
end

function HostAdapterUtils.NewWriteMeta(domain, serviceName, dt, extra)
    local meta = {
        Domain = domain,
        Service = serviceName,
        Dt = dt,
        CommandVersion = SUPPORTED_COMMAND_VERSION,
        SnapshotVersion = SUPPORTED_SNAPSHOT_VERSION,
        Order = "enqueue-sequence",
        ProcessedCommands = 0,
        DroppedCommands = 0,
    }

    if type(extra) == "table" then
        for key, value in pairs(extra) do
            meta[key] = value
        end
    end

    appendReplayEntry({
        Kind = "write",
        Meta = shallowClone(meta),
    })

    return meta
end

function HostAdapterUtils.EnqueueCommand(queue, command, payload, maxPendingCommands, writerContext)
    -- Deterministic ordering contract: writes execute in enqueue order.
    local maxQueue = maxPendingCommands or DEFAULT_MAX_PENDING_COMMANDS
    if #queue >= maxQueue then
        if writerContext then
            writerContext._droppedCommands = (writerContext._droppedCommands or 0) + 1
        end
        return false
    end

    local version = SUPPORTED_COMMAND_VERSION
    if type(payload) == "table" then
        if type(payload.CommandVersion) == "number" then
            version = payload.CommandVersion
        elseif type(payload.__v) == "number" then
            version = payload.__v
        end
    end

    local sequence = #queue + 1
    if writerContext then
        writerContext._enqueueSequence = (writerContext._enqueueSequence or 0) + 1
        sequence = writerContext._enqueueSequence
    end

    table.insert(queue, {
        Command = command,
        Payload = payload,
        Version = version,
        Sequence = sequence,
    })

    return true
end

function HostAdapterUtils.CommitSnapshot(adapter, snapshot)
    if type(snapshot) ~= "table" then
        return false
    end

    if snapshot.SnapshotVersion == nil then
        snapshot.SnapshotVersion = SUPPORTED_SNAPSHOT_VERSION
    end
    if snapshot.HostId == nil then
        snapshot.HostId = _hostId
    end

    local tick = nil
    if adapter and adapter.Kernel and adapter.Kernel.TimeAuthority and adapter.Kernel.TimeAuthority.GetTickIndex then
        tick = adapter.Kernel.TimeAuthority:GetTickIndex()
    end
    snapshot.Tick = tick

    local schema = HostReadSchemas.GetDomainSchema(snapshot and snapshot.Domain)
    if not HostReadSchemas.ValidateSnapshot(schema, snapshot) then
        return false
    end

    local previous = adapter and adapter.LastSample
    local changed = stableDataDiff(previous and previous.Data, snapshot.Data)
    local signature = hashFNV1a32(toDeterministicString(snapshot.Data))
    snapshot.Signature = signature
    snapshot.Diff = {
        Changed = changed,
        ChangedCount = #changed,
    }

    registerParity(snapshot, signature)

    appendReplayEntry({
        Kind = "snapshot",
        Snapshot = {
            SnapshotVersion = snapshot.SnapshotVersion,
            HostId = snapshot.HostId,
            Domain = snapshot.Domain,
            Service = snapshot.Service,
            Tick = snapshot.Tick,
            Dt = snapshot.Dt,
            Signature = signature,
            Diff = snapshot.Diff,
            Data = shallowClone(snapshot.Data),
        },
    })

    adapter.LastSample = snapshot
    return true
end

function HostAdapterUtils.ProcessValidatedCommands(pendingCommands, schemas, handlers, context)
    local processed = 0
    local dropped = 0

    local ordered = {}
    for index = 1, #pendingCommands do
        ordered[index] = pendingCommands[index]
    end

    table.sort(ordered, function(a, b)
        local seqA = a and a.Sequence or 0
        local seqB = b and b.Sequence or 0
        if seqA ~= seqB then
            return seqA < seqB
        end
        return tostring(a and a.Command or "") < tostring(b and b.Command or "")
    end)

    local lastSequence = -math.huge
    for index = 1, #ordered do
        local cmd = ordered[index]
        if type(cmd) ~= "table" then
            dropped += 1
            continue
        end

        local sequence = cmd.Sequence or 0
        if sequence < lastSequence then
            dropped += 1
            continue
        end
        lastSequence = sequence

        if cmd.Version ~= SUPPORTED_COMMAND_VERSION then
            dropped += 1
            continue
        end

        local payload = cmd.Payload

        if HostCommandSchemas.ValidatePayload(schemas, cmd.Command, payload) then
            local handler = handlers[cmd.Command]
            if handler then
                handler(context, payload)
                processed += 1
            else
                dropped += 1
            end
        else
            dropped += 1
        end
    end

    return processed, dropped
end

function HostAdapterUtils.IsPayloadTable(payload)
    return type(payload) == "table"
end

function HostAdapterUtils.IsString(value)
    return type(value) == "string"
end

function HostAdapterUtils.IsNumber(value)
    return type(value) == "number"
end

function HostAdapterUtils.IsBoolean(value)
    return type(value) == "boolean"
end

function HostAdapterUtils.ConfigureReplay(config)
    if type(config) ~= "table" then
        return
    end

    if type(config.Enabled) == "boolean" then
        _replayEnabled = config.Enabled
    end

    if type(config.MaxEntries) == "number" and config.MaxEntries >= 1 then
        _replayMaxEntries = math.floor(config.MaxEntries)
        while #_replayEntries > _replayMaxEntries do
            table.remove(_replayEntries, 1)
        end
    end
end

function HostAdapterUtils.SetHostId(hostId)
    if type(hostId) == "string" and hostId ~= "" then
        _hostId = hostId
    end
end

function HostAdapterUtils.GetReplayEntries()
    local out = {}
    for index = 1, #_replayEntries do
        out[index] = _replayEntries[index]
    end
    return out
end

function HostAdapterUtils.ClearReplayEntries()
    clearTable(_replayEntries)
    _replayCursor = 0
end

function HostAdapterUtils.GetParityErrors()
    local out = {}
    for key, value in pairs(_parityErrors) do
        out[key] = value
    end
    return out
end

function HostAdapterUtils.ClearParityErrors()
    clearTable(_parityErrors)
    clearTable(_parityBaseline)
end

function HostAdapterUtils.ValidateCrossHostSnapshot(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.Data) ~= "table" then
        return false
    end

    if snapshot.SnapshotVersion ~= SUPPORTED_SNAPSHOT_VERSION then
        return false
    end

    local signature = snapshot.Signature
    if type(signature) ~= "string" then
        signature = hashFNV1a32(toDeterministicString(snapshot.Data))
    end

    return registerParity(snapshot, signature)
end

return HostAdapterUtils
