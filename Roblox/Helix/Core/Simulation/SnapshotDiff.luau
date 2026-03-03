local SnapshotDiff = {}

local function sortedEntityIds(entities)
    local ids = {}
    for entityId in pairs(entities or {}) do
        ids[#ids + 1] = entityId
    end
    table.sort(ids)
    return ids
end

local function vecChanged(a, b)
    local ax = a and a.X or 0
    local ay = a and a.Y or 0
    local az = a and a.Z or 0
    local bx = b and b.X or 0
    local by = b and b.Y or 0
    local bz = b and b.Z or 0
    return ax ~= bx or ay ~= by or az ~= bz
end

local function toDiffVec(v)
    return {
        X = v and v.X or 0,
        Y = v and v.Y or 0,
        Z = v and v.Z or 0,
    }
end

function SnapshotDiff:DiffStates(previousState, nextState)
    local prev = type(previousState) == "table" and previousState.Entities or {}
    local nextEntities = type(nextState) == "table" and nextState.Entities or {}

    local prevIds = sortedEntityIds(prev)
    local nextIds = sortedEntityIds(nextEntities)

    local prevSet = {}
    local nextSet = {}
    for index = 1, #prevIds do
        prevSet[prevIds[index]] = true
    end
    for index = 1, #nextIds do
        nextSet[nextIds[index]] = true
    end

    local added = {}
    local removed = {}
    local changed = {}

    for index = 1, #nextIds do
        local entityId = nextIds[index]
        if not prevSet[entityId] then
            added[#added + 1] = entityId
        end
    end

    for index = 1, #prevIds do
        local entityId = prevIds[index]
        if not nextSet[entityId] then
            removed[#removed + 1] = entityId
        end
    end

    for index = 1, #nextIds do
        local entityId = nextIds[index]
        local before = prev[entityId]
        local after = nextEntities[entityId]
        if before and after then
            local transformChanged = vecChanged(before.LocalTransform, after.LocalTransform)
                or vecChanged(before.WorldTransform, after.WorldTransform)
            local parentChanged = before.Parent ~= after.Parent
            if transformChanged or parentChanged then
                changed[#changed + 1] = {
                    EntityId = entityId,
                    Parent = after.Parent,
                    LocalTransform = toDiffVec(after.LocalTransform),
                    WorldTransform = toDiffVec(after.WorldTransform),
                }
            end
        end
    end

    return {
        Added = added,
        Removed = removed,
        Changed = changed,
        AddedCount = #added,
        RemovedCount = #removed,
        ChangedCount = #changed,
    }
end

return SnapshotDiff
