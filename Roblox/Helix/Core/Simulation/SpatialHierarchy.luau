local SpatialHierarchy = {}

local function vec3(x, y, z)
    return { X = x or 0, Y = y or 0, Z = z or 0 }
end

local function accumulate(parentWorld, localTransform)
    return vec3(
        (parentWorld and parentWorld.X or 0) + (localTransform and localTransform.X or 0),
        (parentWorld and parentWorld.Y or 0) + (localTransform and localTransform.Y or 0),
        (parentWorld and parentWorld.Z or 0) + (localTransform and localTransform.Z or 0)
    )
end

local function propagateEntity(world, entityId, parentWorld)
    local entity = world:GetEntity(entityId)
    if not entity then
        return
    end

    local worldTransform = accumulate(parentWorld, entity.LocalTransform)
    world:SetWorldTransform(entityId, worldTransform.X, worldTransform.Y, worldTransform.Z)

    table.sort(entity.Children)
    for index = 1, #entity.Children do
        propagateEntity(world, entity.Children[index], worldTransform)
    end
end

function SpatialHierarchy:Propagate(world)
    local entityIds = world:GetEntityIds()
    for index = 1, #entityIds do
        local entity = world:GetEntity(entityIds[index])
        if entity and entity.Parent == nil then
            propagateEntity(world, entity.Id, nil)
        end
    end
end

return SpatialHierarchy
