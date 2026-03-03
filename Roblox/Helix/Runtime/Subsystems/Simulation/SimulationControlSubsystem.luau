local SimulationControlSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

SimulationControlSubsystem.Reader = nil
SimulationControlSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function SimulationControlSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("SimulationControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)

    self.PendingRewindTick = nil
end

function SimulationControlSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function SimulationControlSubsystem:GetControlSource()
    return self.ControlSource
end

function SimulationControlSubsystem:SetPaused(value)
    local simulation = self.Kernel and self.Kernel.Simulation
    if simulation then
        simulation.Pause = value == true
    end
end

function SimulationControlSubsystem:RequestRewind(targetTick)
    if type(targetTick) == "number" then
        self.PendingRewindTick = math.max(0, math.floor(targetTick))
        return true
    end
    return false
end

function SimulationControlSubsystem:Start()
end

function SimulationControlSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX then
        local simulation = self.Kernel and self.Kernel.Simulation
        local world = simulation and simulation.World
        local rewind = simulation and simulation.Rewind
        local timeAuthority = self.Kernel and self.Kernel.TimeAuthority

        if simulation and world and rewind and timeAuthority and timeAuthority.GetTickIndex then
            local tick = timeAuthority:GetTickIndex()

            if self.PendingRewindTick then
                local frame = rewind:RestoreClosest(self.PendingRewindTick)
                if frame and frame.State then
                    world:RestoreState(frame.State)
                    simulation.Pause = true
                end
                self.PendingRewindTick = nil
            end

            rewind:Capture(tick, world:CloneState())

            if self.Writer and self.Writer.Enqueue then
                self.Writer:Enqueue("SetAttribute", { Key = "HelixPause", Value = simulation.Pause == true })
                self.Writer:Enqueue("SetAttribute", { Key = "HelixRewindFrames", Value = #rewind.Frames })
            end
        end
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function SimulationControlSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return SimulationControlSubsystem
