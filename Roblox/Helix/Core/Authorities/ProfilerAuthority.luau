local ProfilerAuthority = {}

local _initialized = false
local _frameStart = 0
local _activeSections = {}
local _lastFrame = {
    Tick = 0,
    TotalMs = 0,
    Sections = {},
}

local function nowMs()
    return os.clock() * 1000
end

function ProfilerAuthority:Initialize()
    _initialized = true
    _frameStart = 0
    _activeSections = {}
    _lastFrame = {
        Tick = 0,
        TotalMs = 0,
        Sections = {},
    }
end

function ProfilerAuthority:BeginFrame(tick)
    if not _initialized then
        return
    end
    _frameStart = nowMs()
    _activeSections = {}
    _lastFrame = {
        Tick = math.floor(tick or 0),
        TotalMs = 0,
        Sections = {},
    }
end

function ProfilerAuthority:BeginSection(name)
    if not _initialized then
        return
    end
    _activeSections[name] = nowMs()
end

function ProfilerAuthority:EndSection(name)
    if not _initialized then
        return
    end
    local startMs = _activeSections[name]
    if not startMs then
        return
    end
    _activeSections[name] = nil
    _lastFrame.Sections[#_lastFrame.Sections + 1] = {
        Name = name,
        DurationMs = nowMs() - startMs,
    }
end

function ProfilerAuthority:EndFrame()
    if not _initialized then
        return
    end
    local total = nowMs() - _frameStart
    _lastFrame.TotalMs = total
    table.sort(_lastFrame.Sections, function(a, b)
        if a.DurationMs ~= b.DurationMs then
            return a.DurationMs > b.DurationMs
        end
        return tostring(a.Name) < tostring(b.Name)
    end)
end

function ProfilerAuthority:GetLastFrame()
    return _lastFrame
end

function ProfilerAuthority:Shutdown()
    _initialized = false
    _frameStart = 0
    _activeSections = {}
    _lastFrame = {
        Tick = 0,
        TotalMs = 0,
        Sections = {},
    }
end

return ProfilerAuthority
