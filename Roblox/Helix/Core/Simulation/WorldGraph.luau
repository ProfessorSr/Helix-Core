local WorldGraph = {}
WorldGraph.__index = WorldGraph

local function shallowCopy(input)
    local out = {}
    for key, value in pairs(input) do
        out[key] = value
    end
    return out
end

local function vec3(x, y, z)
    return { X = x or 0, Y = y or 0, Z = z or 0 }
end

function WorldGraph.new()
    return setmetatable({
        NextEntityId = 1,
        Entities = {},
        Tick = 0,
    }, WorldGraph)
end

function WorldGraph:CreateEntity(initial)
    local id = self.NextEntityId
    self.NextEntityId += 1

    local entity = {
        Id = id,
        Parent = nil,
        Children = {},
        Components = {},
        LocalTransform = vec3(),
        WorldTransform = vec3(),
    }

    if type(initial) == "table" then
        if type(initial.Components) == "table" then
            entity.Components = shallowCopy(initial.Components)
        end
        if type(initial.LocalTransform) == "table" then
            entity.LocalTransform = vec3(initial.LocalTransform.X, initial.LocalTransform.Y, initial.LocalTransform.Z)
            entity.WorldTransform = vec3(initial.LocalTransform.X, initial.LocalTransform.Y, initial.LocalTransform.Z)
        end
    end

    self.Entities[id] = entity
    return id
end

function WorldGraph:DestroyEntity(entityId)
    local entity = self.Entities[entityId]
    if not entity then
        return false
    end

    if entity.Parent and self.Entities[entity.Parent] then
        local siblings = self.Entities[entity.Parent].Children
        for index = #siblings, 1, -1 do
            if siblings[index] == entityId then
                table.remove(siblings, index)
                break
            end
        end
    end

    for index = 1, #entity.Children do
        local childId = entity.Children[index]
        local child = self.Entities[childId]
        if child then
            child.Parent = nil
        end
    end

    self.Entities[entityId] = nil
    return true
end

function WorldGraph:GetEntity(entityId)
    return self.Entities[entityId]
end

function WorldGraph:GetEntityIds()
    local ids = {}
    for entityId in pairs(self.Entities) do
        ids[#ids + 1] = entityId
    end
    table.sort(ids)
    return ids
end

function WorldGraph:SetParent(entityId, parentId)
    local entity = self.Entities[entityId]
    if not entity then
        return false
    end

    if parentId ~= nil and self.Entities[parentId] == nil then
        return false
    end

    if entity.Parent and self.Entities[entity.Parent] then
        local oldChildren = self.Entities[entity.Parent].Children
        for index = #oldChildren, 1, -1 do
            if oldChildren[index] == entityId then
                table.remove(oldChildren, index)
                break
            end
        end
    end

    entity.Parent = parentId
    if parentId then
        self.Entities[parentId].Children[#self.Entities[parentId].Children + 1] = entityId
        table.sort(self.Entities[parentId].Children)
    end

    return true
end

function WorldGraph:SetComponent(entityId, componentName, value)
    local entity = self.Entities[entityId]
    if not entity or type(componentName) ~= "string" then
        return false
    end

    entity.Components[componentName] = value
    return true
end

function WorldGraph:GetComponent(entityId, componentName)
    local entity = self.Entities[entityId]
    if not entity or type(componentName) ~= "string" then
        return nil
    end
    return entity.Components[componentName]
end

function WorldGraph:SetLocalTransform(entityId, x, y, z)
    local entity = self.Entities[entityId]
    if not entity then
        return false
    end

    entity.LocalTransform = vec3(x, y, z)
    return true
end

function WorldGraph:SetWorldTransform(entityId, x, y, z)
    local entity = self.Entities[entityId]
    if not entity then
        return false
    end

    entity.WorldTransform = vec3(x, y, z)
    return true
end

function WorldGraph:CloneState()
    local clone = {
        NextEntityId = self.NextEntityId,
        Tick = self.Tick,
        Entities = {},
    }

    for entityId, entity in pairs(self.Entities) do
        clone.Entities[entityId] = {
            Id = entity.Id,
            Parent = entity.Parent,
            Children = shallowCopy(entity.Children),
            Components = shallowCopy(entity.Components),
            LocalTransform = vec3(entity.LocalTransform.X, entity.LocalTransform.Y, entity.LocalTransform.Z),
            WorldTransform = vec3(entity.WorldTransform.X, entity.WorldTransform.Y, entity.WorldTransform.Z),
        }
    end

    return clone
end

function WorldGraph:RestoreState(state)
    if type(state) ~= "table" or type(state.Entities) ~= "table" then
        return false
    end

    self.NextEntityId = state.NextEntityId or self.NextEntityId
    self.Tick = state.Tick or self.Tick
    self.Entities = {}

    for entityId, entity in pairs(state.Entities) do
        self.Entities[entityId] = {
            Id = entity.Id,
            Parent = entity.Parent,
            Children = shallowCopy(entity.Children or {}),
            Components = shallowCopy(entity.Components or {}),
            LocalTransform = vec3(entity.LocalTransform and entity.LocalTransform.X, entity.LocalTransform and entity.LocalTransform.Y, entity.LocalTransform and entity.LocalTransform.Z),
            WorldTransform = vec3(entity.WorldTransform and entity.WorldTransform.X, entity.WorldTransform and entity.WorldTransform.Y, entity.WorldTransform and entity.WorldTransform.Z),
        }
    end

    return true
end

return WorldGraph
