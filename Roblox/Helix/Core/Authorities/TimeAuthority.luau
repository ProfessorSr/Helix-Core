local TimeAuthority = {}

local _tickIndex = 0
local _elapsedSeconds = 0
local _fixedStep = 0
local _locked = false

function TimeAuthority:Initialize(fixedStepSeconds)
    _fixedStep = fixedStepSeconds or _fixedStep
    if _fixedStep == 0 then
        _fixedStep = 1 / 60
    end
    _tickIndex = 0
    _elapsedSeconds = 0
end

function TimeAuthority:Advance()
    _tickIndex += 1
    _elapsedSeconds += _fixedStep
end

function TimeAuthority:GetTickIndex()
    return _tickIndex
end

function TimeAuthority:GetElapsedSeconds()
    return _elapsedSeconds
end

function TimeAuthority:GetFixedStep()
    return _fixedStep
end

function TimeAuthority:GetTicksPerSecond()
    return 1 / _fixedStep
end

function TimeAuthority:Lock()
    _locked = true
end

function TimeAuthority:IsLocked()
    return _locked
end

return TimeAuthority
