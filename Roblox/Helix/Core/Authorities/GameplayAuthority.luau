local GameplayAuthority = {}

local _kernel = nil
local _initialized = false
local _queuedInputsByTick = {}
local _systems = {}
local _schemaAuthority = nil
local _lastFrame = {
    Tick = 0,
    InputCount = 0,
    SystemCount = 0,
}

local function sortSystems()
    table.sort(_systems, function(a, b)
        if a.Priority ~= b.Priority then
            return a.Priority < b.Priority
        end
        return tostring(a.Name) < tostring(b.Name)
    end)
end

function GameplayAuthority:Initialize(kernel, schemaAuthority)
    if _initialized then
        warn("[GameplayAuthority] Initialize called more than once; ignoring.")
        return false
    end

    _kernel = kernel
    _schemaAuthority = schemaAuthority
    _initialized = true
    _queuedInputsByTick = {}
    _systems = {}
    _lastFrame = {
        Tick = 0,
        InputCount = 0,
        SystemCount = 0,
    }
    return true
end

function GameplayAuthority:IsInitialized()
    return _initialized
end

function GameplayAuthority:RegisterSystem(name, handler, priority)
    assert(type(name) == "string" and name ~= "", "name must be a non-empty string")
    assert(type(handler) == "function", "handler must be a function")

    _systems[#_systems + 1] = {
        Name = name,
        Handler = handler,
        Priority = priority or 100,
    }
    sortSystems()
end

function GameplayAuthority:QueueInput(playerId, tick, inputFrame)
    if not _initialized then
        return false
    end
    if type(tick) ~= "number" then
        return false
    end
    if _schemaAuthority and _schemaAuthority.ValidatePayload and not _schemaAuthority:ValidatePayload("Input", inputFrame) then
        return false
    end

    local integerTick = math.floor(tick)
    local bucket = _queuedInputsByTick[integerTick]
    if not bucket then
        bucket = {}
        _queuedInputsByTick[integerTick] = bucket
    end

    bucket[#bucket + 1] = {
        PlayerId = tostring(playerId or "server"),
        Tick = integerTick,
        Input = inputFrame or {},
    }

    return true
end

function GameplayAuthority:ProcessTick(tick, dt)
    if not _initialized then
        return 0
    end

    local integerTick = math.floor(tick or 0)
    local frameInputs = _queuedInputsByTick[integerTick] or {}
    _queuedInputsByTick[integerTick] = nil

    local networkingAuthority = _kernel and _kernel.NetworkingAuthority
    if networkingAuthority and networkingAuthority.ConsumeInputsForTick then
        local authoritativeInputs = networkingAuthority:ConsumeInputsForTick(integerTick)
        for index = 1, #authoritativeInputs do
            local input = authoritativeInputs[index]
            frameInputs[#frameInputs + 1] = {
                PlayerId = input.PlayerId,
                Tick = integerTick,
                Input = input.Input,
                Sequence = input.Sequence,
            }
        end
    end

    table.sort(frameInputs, function(a, b)
        if a.PlayerId ~= b.PlayerId then
            return a.PlayerId < b.PlayerId
        end
        return a.Tick < b.Tick
    end)

    local simulation = _kernel and _kernel.Simulation
    local lockstep = simulation and simulation.Lockstep
    if lockstep and lockstep.QueueInput then
        for index = 1, #frameInputs do
            local frame = frameInputs[index]
            lockstep:QueueInput(frame.PlayerId, integerTick, frame.Input)
        end
    end

    local context = {
        Kernel = _kernel,
        Tick = integerTick,
        Dt = dt,
        Inputs = frameInputs,
    }

    local ranSystems = 0
    for index = 1, #_systems do
        local system = _systems[index]
        local ok, err = pcall(system.Handler, context)
        if not ok then
            warn(string.format("[GameplayAuthority] System '%s' failed: %s", system.Name, tostring(err)))
        else
            ranSystems += 1
        end
    end

    _lastFrame = {
        Tick = integerTick,
        InputCount = #frameInputs,
        SystemCount = ranSystems,
    }

    return #frameInputs
end

function GameplayAuthority:GetLastFrameStats()
    return _lastFrame
end

function GameplayAuthority:Shutdown()
    _kernel = nil
    _schemaAuthority = nil
    _initialized = false
    _queuedInputsByTick = {}
    _systems = {}
    _lastFrame = {
        Tick = 0,
        InputCount = 0,
        SystemCount = 0,
    }
end

return GameplayAuthority
