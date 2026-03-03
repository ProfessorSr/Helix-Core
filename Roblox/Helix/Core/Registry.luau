
----------------------------------------------------------------
-- FILE: Registry
----------------------------------------------------------------

local Registry = {}
local _subsystems = {}
local _locked = false

function Registry:Register(name, subsystem, priority)
    assert(not _locked, "Registry is locked")
    _subsystems[name] = {
        name = name,
        instance = subsystem,
        priority = priority or 100
    }
end

function Registry:Unregister(name)
    assert(not _locked, "Registry is locked")
    _subsystems[name] = nil
end

function Registry:Clear()
    assert(not _locked, "Registry is locked")
    _subsystems = {}
end

function Registry:Lock()
    _locked = true
end

function Registry:GetOrdered()
    local list = {}
    for _, data in pairs(_subsystems) do
        table.insert(list, data)
    end
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return tostring(a.name) < tostring(b.name)
    end)
    return list
end

return Registry
