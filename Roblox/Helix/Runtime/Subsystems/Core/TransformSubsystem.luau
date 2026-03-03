local TransformSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

TransformSubsystem.Reader = nil
TransformSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function TransformSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("TransformControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function TransformSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function TransformSubsystem:GetControlSource()
    return self.ControlSource
end

function TransformSubsystem:Start()
end

function TransformSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX then
        local simulation = self.Kernel and self.Kernel.Simulation
        local world = simulation and simulation.World
        local spatial = simulation and simulation.Spatial

        if world and spatial then
            spatial:Propagate(world)

            local entityIds = world:GetEntityIds()
            if self.Writer and self.Writer.Enqueue then
                self.Writer:Enqueue("SetAttribute", { Key = "HelixEntityCount", Value = #entityIds })

                for index = 1, #entityIds do
                    local entityId = entityIds[index]
                    local entity = world:GetEntity(entityId)
                    if entity and entity.WorldTransform then
                        self.Writer:Enqueue("SetEntityTransform", {
                            EntityId = entityId,
                            PX = entity.WorldTransform.X or 0,
                            PY = entity.WorldTransform.Y or 0,
                            PZ = entity.WorldTransform.Z or 0,
                        })
                    end
                end
            end
        end
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function TransformSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return TransformSubsystem
