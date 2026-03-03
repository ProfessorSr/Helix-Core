--[[
----------------------------------------------------------------
-- FILE: RuntimeHost
-- TYPE: Health-Gated Runtime Loader
-- LAST UPDATED (UTC):
----------------------------------------------------------------
]]

local RuntimeHost = {}

RuntimeHost._loaded = {}
RuntimeHost._registry = nil

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

local function ensureControlSwitch(subsystem, defaultSource)
    if type(subsystem) ~= "table" then
        return
    end

    local hadCustomSetControlSource = subsystem.SetControlSource ~= nil
    local originalTick = subsystem.Tick

    if subsystem.ControlSource == nil then
        subsystem.ControlSource = normalizeSource(defaultSource)
    end

    if subsystem.SetControlSource == nil then
        function subsystem:SetControlSource(source)
            self.ControlSource = normalizeSource(source)
        end
    end

    if subsystem.GetControlSource == nil then
        function subsystem:GetControlSource()
            return normalizeSource(self.ControlSource)
        end
    end

    -- Auto-wire switchable tick behavior for legacy/pass-through subsystems.
    -- Custom switch implementations (Camera/Input/Audio) keep their own Tick logic.
    if not hadCustomSetControlSource and originalTick and not subsystem.__HelixTickWrapped then
        subsystem.__HelixOriginalTick = originalTick

        function subsystem:HostTick(dt)
            if self.Reader and self.Reader.Tick then
                self.Reader:Tick(dt)
            end
            if self.Writer and self.Writer.Tick then
                self.Writer:Tick(dt)
            end
        end

        function subsystem:HelixTick(dt)
            self:__HelixOriginalTick(dt)
        end

        function subsystem:Tick(dt)
            local source = normalizeSource(self.ControlSource)
            if source == SOURCE_HOST then
                return self:HostTick(dt)
            end
            return self:HelixTick(dt)
        end

        subsystem.__HelixTickWrapped = true
    end
end

local function sortByPhase(a, b)
    local phaseA = a.Phase or 0
    local phaseB = b.Phase or 0

    if phaseA ~= phaseB then
        return phaseA < phaseB
    end

    -- Deterministic tie-breaker (Domain first, then Module name)
    local domainA = tostring(a.Domain or "")
    local domainB = tostring(b.Domain or "")

    if domainA ~= domainB then
        return domainA < domainB
    end

    local nameA = a.Module and a.Module.Name or ""
    local nameB = b.Module and b.Module.Name or ""

    return nameA < nameB
end

local function dependencyNames(config)
    if type(config.Dependencies) ~= "table" then
        return {}
    end
    local out = {}
    for index = 1, #config.Dependencies do
        local value = config.Dependencies[index]
        if type(value) == "string" and value ~= "" then
            out[#out + 1] = value
        end
    end
    table.sort(out)
    return out
end

local function buildManifestLookup(manifest)
    local byName = {}
    for index = 1, #manifest do
        local config = manifest[index]
        local name = config and config.Name
        if type(name) ~= "string" or name == "" then
            error(string.format("[RuntimeHost] Manifest entry missing Name at index %d", index))
        end
        if byName[name] ~= nil then
            error(string.format("[RuntimeHost] Duplicate subsystem name in manifest: %s", name))
        end
        byName[name] = config
    end
    return byName
end

local function topologicalLoadOrder(manifest)
    local byName = buildManifestLookup(manifest)
    local indegree = {}
    local edges = {}
    local pending = {}

    for index = 1, #manifest do
        local config = manifest[index]
        local name = config.Name
        indegree[name] = 0
        edges[name] = {}
    end

    for index = 1, #manifest do
        local config = manifest[index]
        local name = config.Name
        local deps = dependencyNames(config)
        for depIndex = 1, #deps do
            local dep = deps[depIndex]
            if not byName[dep] then
                error(string.format("[RuntimeHost] Dependency '%s' not found for subsystem '%s'", dep, name))
            end
            edges[dep][#edges[dep] + 1] = name
            indegree[name] += 1
        end
    end

    for index = 1, #manifest do
        local config = manifest[index]
        if indegree[config.Name] == 0 then
            pending[#pending + 1] = config
        end
    end
    table.sort(pending, sortByPhase)

    local ordered = {}
    while #pending > 0 do
        local current = table.remove(pending, 1)
        ordered[#ordered + 1] = current

        local outgoing = edges[current.Name]
        table.sort(outgoing)
        for edgeIndex = 1, #outgoing do
            local dependentName = outgoing[edgeIndex]
            indegree[dependentName] -= 1
            if indegree[dependentName] == 0 then
                pending[#pending + 1] = byName[dependentName]
            end
        end
        table.sort(pending, sortByPhase)
    end

    if #ordered ~= #manifest then
        error("[RuntimeHost] Dependency cycle detected in subsystem manifest.")
    end

    return ordered
end

function RuntimeHost:Start(runtimeFolder, kernel)
    assert(runtimeFolder, "[RuntimeHost] Missing runtimeFolder")
    assert(kernel, "[RuntimeHost] Missing kernel")

    local Registry = require(
        runtimeFolder.Parent
            :WaitForChild("Core")
            :WaitForChild("Registry")
    )
    self._registry = Registry

    -- Ensure a clean lifecycle when Start is called more than once.
    if #self._loaded > 0 then
        self:Stop()
    end

    local manifestModule = runtimeFolder:WaitForChild("SubsystemManifest")
    local Manifest = require(manifestModule)
    local sortedManifest = topologicalLoadOrder(Manifest)

    local defaultSource = SOURCE_HELIX
    if kernel.Config and kernel.Config.Get then
        defaultSource = normalizeSource(kernel.Config:Get("DefaultSubsystemControlSource") or defaultSource)
    end

    for _, config in ipairs(sortedManifest) do
        assert(config.Module, "[RuntimeHost] Manifest entry missing Module")

        local subsystem = require(config.Module)

        ensureControlSwitch(subsystem, defaultSource)

        local reader = nil
        local writer = nil

        if config.ReaderModule then
            reader = require(config.ReaderModule)
        end

        if config.WriterModule then
            writer = require(config.WriterModule)
        end

        -- Initialize host boundary if supported
        if reader and reader.Initialize then
            reader:Initialize(kernel)
        end

        if writer and writer.Initialize then
            writer:Initialize(kernel)
        end

        if subsystem.Init then
            subsystem:Init(kernel, reader, writer)
        end

        if subsystem.Start then
            subsystem:Start()
        end

        -- Register subsystem for deterministic ticking
        local registryKey = config.Module and config.Module.Name or "Unknown"
        Registry:Register(
            registryKey,
            subsystem,
            config.Phase or 0
        )

        table.insert(self._loaded, {
            Subsystem = subsystem,
            Reader = reader,
            Writer = writer,
            RegistryKey = registryKey,
        })

        local debugEnabled = false

        if kernel.Config and kernel.Config.Get then
            debugEnabled = kernel.Config:Get("DebugLogging") == true
        end

        if debugEnabled then
            local source = "Unknown"
            if subsystem.GetControlSource then
                source = tostring(subsystem:GetControlSource())
            elseif subsystem.ControlSource ~= nil then
                source = tostring(subsystem.ControlSource)
            end
            print(string.format(
                "[RuntimeHost] Loaded Subsystem: %s | Domain=%s | Phase=%s | Source=%s",
                config.Module and config.Module.Name or "Unknown",
                tostring(config.Domain or "Unknown"),
                tostring(config.Phase or 0),
                source
            ))
        end
    end
end


function RuntimeHost:Stop()
    for index = #self._loaded, 1, -1 do
        local entry = self._loaded[index]
        if self._registry and entry.RegistryKey then
            pcall(function()
                self._registry:Unregister(entry.RegistryKey)
            end)
        end

        if entry.Subsystem and entry.Subsystem.Stop then
            entry.Subsystem:Stop()
        end

        if entry.Writer and entry.Writer.Shutdown then
            entry.Writer:Shutdown()
        end

        if entry.Reader and entry.Reader.Shutdown then
            entry.Reader:Shutdown()
        end
    end

    self._loaded = {}
end

return RuntimeHost
