local DevTools = {}
DevTools.__index = DevTools

function DevTools.new()
    return setmetatable({
        OverlayEnabled = true,
        InspectorEntityId = nil,
        LastOverlay = nil,
    }, DevTools)
end

function DevTools:SetOverlayEnabled(value)
    self.OverlayEnabled = value == true
end

function DevTools:SetInspectorEntity(entityId)
    self.InspectorEntityId = entityId
end

function DevTools:BuildOverlay(world, tick, collisions)
    if not self.OverlayEnabled then
        self.LastOverlay = nil
        return nil
    end

    local entityIds = world:GetEntityIds()
    local inspector = nil
    if self.InspectorEntityId then
        local entity = world:GetEntity(self.InspectorEntityId)
        if entity then
            inspector = {
                Id = entity.Id,
                Parent = entity.Parent,
                LocalTransform = {
                    X = entity.LocalTransform and entity.LocalTransform.X or 0,
                    Y = entity.LocalTransform and entity.LocalTransform.Y or 0,
                    Z = entity.LocalTransform and entity.LocalTransform.Z or 0,
                },
                WorldTransform = {
                    X = entity.WorldTransform and entity.WorldTransform.X or 0,
                    Y = entity.WorldTransform and entity.WorldTransform.Y or 0,
                    Z = entity.WorldTransform and entity.WorldTransform.Z or 0,
                },
                Components = entity.Components,
            }
        end
    end

    self.LastOverlay = {
        Tick = tick,
        EntityCount = #entityIds,
        CollisionCount = collisions and #collisions or 0,
        InspectorEntityId = self.InspectorEntityId,
        Inspector = inspector,
    }

    return self.LastOverlay
end

return DevTools
