local StepDebuggerSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

StepDebuggerSubsystem.Reader = nil
StepDebuggerSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function StepDebuggerSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("StepDebuggerControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function StepDebuggerSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function StepDebuggerSubsystem:GetControlSource()
    return self.ControlSource
end

function StepDebuggerSubsystem:Start()
end

function StepDebuggerSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX then
        local simulation = self.Kernel and self.Kernel.Simulation
        local world = simulation and simulation.World
        local devTools = simulation and simulation.DevTools
        local timeAuthority = self.Kernel and self.Kernel.TimeAuthority
        local profiler = self.Kernel and self.Kernel.ProfilerAuthority
        local networkingAuthority = self.Kernel and self.Kernel.NetworkingAuthority

        if simulation and world and devTools and timeAuthority and timeAuthority.GetTickIndex then
            local overlay = devTools:BuildOverlay(world, timeAuthority:GetTickIndex(), simulation.LastCollisions)
            simulation.LastOverlay = overlay
            local profilerFrame = profiler and profiler.GetLastFrame and profiler:GetLastFrame() or nil
            local netFrame = networkingAuthority and networkingAuthority.GetLastFrame and networkingAuthority:GetLastFrame() or nil
            local recentRejects = networkingAuthority and networkingAuthority.GetRecentRejects and networkingAuthority:GetRecentRejects() or nil
            local diff = simulation.LastStateDiff
            local topSection = nil
            if profilerFrame and profilerFrame.Sections and #profilerFrame.Sections > 0 then
                topSection = profilerFrame.Sections[1]
            end

            if overlay and self.Writer and self.Writer.Enqueue then
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayTick", Value = overlay.Tick })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayEntities", Value = overlay.EntityCount })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayCollisions", Value = overlay.CollisionCount })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayBroadphasePairs", Value = (simulation.LastBroadphase and simulation.LastBroadphase.PairCount) or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayConstraintSolves", Value = simulation.LastConstraintsSolved or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayDiffChanged", Value = (diff and diff.ChangedCount) or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayDiffAdded", Value = (diff and diff.AddedCount) or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayDiffRemoved", Value = (diff and diff.RemovedCount) or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayInspectorEntityId", Value = overlay.InspectorEntityId or 0 })
                if overlay.Inspector and overlay.Inspector.WorldTransform then
                    self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayInspectorX", Value = overlay.Inspector.WorldTransform.X or 0 })
                    self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayInspectorY", Value = overlay.Inspector.WorldTransform.Y or 0 })
                    self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayInspectorZ", Value = overlay.Inspector.WorldTransform.Z or 0 })
                end
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayStateHash", Value = simulation.LastStateHash or "0" })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayProfilerMs", Value = (profilerFrame and profilerFrame.TotalMs) or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayProfilerTopName", Value = (topSection and topSection.Name) or "" })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayProfilerTopMs", Value = (topSection and topSection.DurationMs) or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayNetTick", Value = (netFrame and netFrame.Tick) or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayNetInputs", Value = (netFrame and netFrame.InputCount) or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayNetRejects", Value = (netFrame and netFrame.RejectCount) or 0 })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixOverlayNetRecentRejects", Value = recentRejects and #recentRejects or 0 })
            end
        end
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function StepDebuggerSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return StepDebuggerSubsystem
