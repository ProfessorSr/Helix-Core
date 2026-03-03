local WorldSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

WorldSubsystem.Reader = nil
WorldSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function WorldSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("WorldControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
    self.InitializedWorld = false
end

function WorldSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function WorldSubsystem:GetControlSource()
    return self.ControlSource
end

function WorldSubsystem:Start()
end

function WorldSubsystem:BootstrapWorldGraph(world)
    if self.InitializedWorld then
        return
    end

    local rootId = world:CreateEntity({
        LocalTransform = { X = 0, Y = 8, Z = 0 },
        Components = {
            Name = "Root",
            Bounds = { Radius = 1.5 },
            Body = {
                Dynamic = true,
                Mass = 2.0,
                VX = 0,
                VY = 0,
                VZ = 0,
                LinearDamping = 0.02,
                Restitution = 0.15,
                Friction = 0.2,
            },
        },
    })

    local childId = world:CreateEntity({
        LocalTransform = { X = 4, Y = 0, Z = 0 },
        Components = {
            Name = "Child",
            Bounds = { Radius = 1.0 },
            Body = {
                Dynamic = true,
                Mass = 1.0,
                VX = 0,
                VY = 0,
                VZ = 0,
                LinearDamping = 0.02,
                Restitution = 0.1,
                Friction = 0.25,
            },
        },
    })

    world:SetParent(childId, rootId)

    -- Host binding IDs are deterministic and decoupled from host instances.
    world:SetComponent(rootId, "HostBinding", { EntityId = rootId })
    world:SetComponent(childId, "HostBinding", { EntityId = childId })

    self.InitializedWorld = true
end

function WorldSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX then
        local simulation = self.Kernel and self.Kernel.Simulation
        local world = simulation and simulation.World
        if world then
            self:BootstrapWorldGraph(world)
            if self.Kernel and self.Kernel.TimeAuthority and self.Kernel.TimeAuthority.GetTickIndex then
                world.Tick = self.Kernel.TimeAuthority:GetTickIndex()
            end

            if self.Writer and self.Writer.Enqueue then
                self.Writer:Enqueue("SetGravity", { Value = 196.2 })
                self.Writer:Enqueue("SetFallenPartsDestroyHeight", { Value = -500 })
            end
        end
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function WorldSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return WorldSubsystem
