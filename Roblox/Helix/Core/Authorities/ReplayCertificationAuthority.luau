local ReplayCertificationAuthority = {}

local _initialized = false
local _active = false
local _scenarioId = nil
local _tickHashes = {}
local _issues = {}
local _baselineByScenario = {}

local function deterministicDigest(items)
    local acc = 2166136261
    for index = 1, #items do
        local item = tostring(items[index])
        for ch = 1, #item do
            acc = bit32.bxor(acc, string.byte(item, ch))
            acc = (acc * 16777619) % 4294967296
        end
    end
    return string.format("%08x", acc)
end

local function resetActiveState()
    _tickHashes = {}
    _issues = {}
    _active = false
    _scenarioId = nil
end

function ReplayCertificationAuthority:Initialize()
    _initialized = true
    resetActiveState()
end

function ReplayCertificationAuthority:BeginScenario(scenarioId)
    if not _initialized then
        return false
    end
    if _active then
        return false
    end
    _active = true
    _scenarioId = tostring(scenarioId or "default")
    _tickHashes = {}
    _issues = {}
    return true
end

function ReplayCertificationAuthority:RecordTick(tick, stateHash)
    if not _active then
        return false
    end
    if type(tick) ~= "number" then
        return false
    end

    local integerTick = math.floor(tick)
    local hash = tostring(stateHash or "0")
    _tickHashes[integerTick] = hash
    return true
end

function ReplayCertificationAuthority:EndScenario()
    if not _active then
        return nil
    end

    local ticks = {}
    for tick in pairs(_tickHashes) do
        ticks[#ticks + 1] = tick
    end
    table.sort(ticks)

    for index = 2, #ticks do
        if ticks[index] ~= ticks[index - 1] + 1 then
            _issues[#_issues + 1] = string.format("gap:%d->%d", ticks[index - 1], ticks[index])
        end
    end

    local digestItems = {}
    for index = 1, #ticks do
        local tick = ticks[index]
        digestItems[#digestItems + 1] = string.format("%d:%s", tick, _tickHashes[tick])
    end
    local digest = deterministicDigest(digestItems)

    local certificate = {
        ScenarioId = _scenarioId,
        TickCount = #ticks,
        FirstTick = ticks[1],
        LastTick = ticks[#ticks],
        Digest = digest,
        Issues = _issues,
    }

    _active = false
    _scenarioId = nil
    return certificate
end

function ReplayCertificationAuthority:CertifyAgainstBaseline(certificate)
    if type(certificate) ~= "table" then
        return false, "invalid_certificate"
    end
    if type(certificate.ScenarioId) ~= "string" then
        return false, "invalid_scenario"
    end

    local baseline = _baselineByScenario[certificate.ScenarioId]
    if not baseline then
        _baselineByScenario[certificate.ScenarioId] = {
            Digest = certificate.Digest,
            TickCount = certificate.TickCount,
        }
        return true, "baseline_created"
    end

    if baseline.Digest ~= certificate.Digest or baseline.TickCount ~= certificate.TickCount then
        return false, "determinism_mismatch"
    end

    return true, "certified"
end

function ReplayCertificationAuthority:Reset()
    _baselineByScenario = {}
    resetActiveState()
end

return ReplayCertificationAuthority
