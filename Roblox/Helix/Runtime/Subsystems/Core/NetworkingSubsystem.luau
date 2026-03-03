local NetworkingSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

NetworkingSubsystem.Reader = nil
NetworkingSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function NetworkingSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("NetworkingControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function NetworkingSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function NetworkingSubsystem:GetControlSource()
    return self.ControlSource
end

function NetworkingSubsystem:Start()
end

function NetworkingSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX then
        local simulation = self.Kernel and self.Kernel.Simulation
        local world = simulation and simulation.World
        local lockstep = simulation and simulation.Lockstep
        local timeAuthority = self.Kernel and self.Kernel.TimeAuthority
        local networkingAuthority = self.Kernel and self.Kernel.NetworkingAuthority

        if world and lockstep and timeAuthority and timeAuthority.GetTickIndex then
            local tick = timeAuthority:GetTickIndex()
            local stateHash = simulation.LastStateHash or "0"
            local stateTick = simulation.LastPhysicsTick or tick
            lockstep:RecordStateHash(stateTick, stateHash)
            local inputs = simulation.LastLockstepInputs or {}
            local authoritativeFrame = networkingAuthority and networkingAuthority.GetLastFrame and networkingAuthority:GetLastFrame() or nil
            local recentRejects = networkingAuthority and networkingAuthority.GetRecentRejects and networkingAuthority:GetRecentRejects() or nil

            if self.Writer and self.Writer.Enqueue then
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixTick", Value = tick })
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixPhysicsTick", Value = stateTick })
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixStateHash", Value = stateHash })
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixInputs", Value = #inputs })
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixReconcileMismatches", Value = lockstep.ReconciliationMismatches })
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixAuthTick", Value = (authoritativeFrame and authoritativeFrame.Tick) or 0 })
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixAuthInputs", Value = (authoritativeFrame and authoritativeFrame.InputCount) or 0 })
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixAuthRejectCount", Value = (authoritativeFrame and authoritativeFrame.RejectCount) or 0 })
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixAuthLastRejectReason", Value = (authoritativeFrame and authoritativeFrame.LastRejectReason) or "" })
                self.Writer:Enqueue("SetReplicationAttribute", { Key = "HelixAuthRecentRejects", Value = recentRejects and #recentRejects or 0 })
            end
        end
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function NetworkingSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return NetworkingSubsystem
