local AudioReader = {}

local HostAdapterUtils = require(script.Parent.Parent:WaitForChild("HostAdapterUtils"))

local SERVICE_NAME = "SoundService"

function AudioReader:Initialize(kernel)
    self.Kernel = kernel
    self.Service = HostAdapterUtils.TryGetService(SERVICE_NAME)
    self.LastSample = nil
end

function AudioReader:Tick(dt)
    if not self.Service then
        return
    end

    local sample = HostAdapterUtils.NewSnapshot("Audio", SERVICE_NAME, dt)

    -- SoundService has no global Volume property; keep stable metadata fields only.
    sample.Data.MasterVolume = HostAdapterUtils.TryReadProperty(self.Service, "HelixMasterVolume", nil)
    sample.Data.BusMaster = HostAdapterUtils.TryReadProperty(self.Service, "HelixBus_Master", nil)
    sample.Data.BusMusic = HostAdapterUtils.TryReadProperty(self.Service, "HelixBus_Music", nil)
    sample.Data.BusSFX = HostAdapterUtils.TryReadProperty(self.Service, "HelixBus_SFX", nil)
    sample.Data.BusAmbience = HostAdapterUtils.TryReadProperty(self.Service, "HelixBus_Ambience", nil)
    sample.Data.AmbientReverb = HostAdapterUtils.TryReadProperty(self.Service, "AmbientReverb", nil)
    sample.Data.RespectFilteringEnabled = HostAdapterUtils.TryReadProperty(self.Service, "RespectFilteringEnabled", nil)

    HostAdapterUtils.CommitSnapshot(self, sample)
end

function AudioReader:ReadSnapshot()
    return self.LastSample
end

function AudioReader:Shutdown()
    self.LastSample = nil
    self.Service = nil
    self.Kernel = nil
end

return AudioReader
