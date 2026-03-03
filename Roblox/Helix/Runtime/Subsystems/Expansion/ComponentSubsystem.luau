local ComponentSubsystem = {}

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

ComponentSubsystem.Reader = nil
ComponentSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function ComponentSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("ComponentControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)
end

function ComponentSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function ComponentSubsystem:GetControlSource()
    return self.ControlSource
end

function ComponentSubsystem:Start()
end

function ComponentSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX then
        local simulation = self.Kernel and self.Kernel.Simulation
        local world = simulation and simulation.World

        if world then
            local ids = world:GetEntityIds()
            for index = 1, #ids do
                local entityId = ids[index]
                local life = world:GetComponent(entityId, "Lifetime") or 0
                world:SetComponent(entityId, "Lifetime", life + 1)
            end

            if self.Writer and self.Writer.Enqueue then
                self.Writer:Enqueue("SetServiceAttribute", { Key = "HelixEntityCount", Value = #ids })
                self.Writer:Enqueue("SetServiceAttribute", { Key = "HelixECSUpdated", Value = true })
            end
        end
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function ComponentSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return ComponentSubsystem
