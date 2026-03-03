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
    local sortedManifest = {}
    for index = 1, #Manifest do
        sortedManifest[index] = Manifest[index]
    end

    table.sort(sortedManifest, sortByPhase)

    for _, config in ipairs(sortedManifest) do
        assert(config.Module, "[RuntimeHost] Manifest entry missing Module")

        local subsystem = require(config.Module)

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
            print(string.format(
                "[RuntimeHost] Loaded Subsystem: %s | Domain=%s | Phase=%s",
                config.Module and config.Module.Name or "Unknown",
                tostring(config.Domain or "Unknown"),
                tostring(config.Phase or 0)
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
