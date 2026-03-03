local UISubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

UISubsystem.Reader = nil
UISubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function UISubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer
    self.Enabled = true

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("UIControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function UISubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function UISubsystem:GetControlSource()
    return self.ControlSource
end

function UISubsystem:Start()
end

function UISubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX and self.Writer and self.Writer.Enqueue then
        local tick = 0
        if self.Kernel and self.Kernel.TimeAuthority and self.Kernel.TimeAuthority.GetTickIndex then
            tick = self.Kernel.TimeAuthority:GetTickIndex()
        end

        -- Deterministic pulse to prove Helix controls the host UI boundary.
        self.Enabled = (tick % 120) < 90
        self.Writer:Enqueue("SetCoreGuiEnabled", { GuiType = "All", Enabled = self.Enabled })

        local simulation = self.Kernel and self.Kernel.Simulation
        local overlay = simulation and simulation.LastOverlay
        local diff = simulation and simulation.LastStateDiff
        local profiler = self.Kernel and self.Kernel.ProfilerAuthority
        local networking = self.Kernel and self.Kernel.NetworkingAuthority
        local profilerFrame = profiler and profiler.GetLastFrame and profiler:GetLastFrame() or nil
        local netFrame = networking and networking.GetLastFrame and networking:GetLastFrame() or nil
        local topSection = nil
        if profilerFrame and profilerFrame.Sections and #profilerFrame.Sections > 0 then
            topSection = profilerFrame.Sections[1]
        end

        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugTick", Value = tick })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugEntityCount", Value = (overlay and overlay.EntityCount) or 0 })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugCollisionCount", Value = (overlay and overlay.CollisionCount) or 0 })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugStateHash", Value = (simulation and simulation.LastStateHash) or "0" })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugDiffChanged", Value = (diff and diff.ChangedCount) or 0 })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugAuthTick", Value = (netFrame and netFrame.Tick) or 0 })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugAuthInputs", Value = (netFrame and netFrame.InputCount) or 0 })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugAuthRejects", Value = (netFrame and netFrame.RejectCount) or 0 })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugProfilerTotalMs", Value = (profilerFrame and profilerFrame.TotalMs) or 0 })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugProfilerTopSection", Value = (topSection and topSection.Name) or "" })
        self.Writer:Enqueue("SetAttribute", { Key = "HelixDebugProfilerTopMs", Value = (topSection and topSection.DurationMs) or 0 })
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function UISubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return UISubsystem
