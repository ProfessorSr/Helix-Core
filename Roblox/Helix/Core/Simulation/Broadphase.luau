local Broadphase = {}

local function makeProxy(entityId, entity, bounds)
    local radius = bounds.Radius or 0
    local world = entity.WorldTransform or {}
    local x = world.X or 0
    return {
        EntityId = entityId,
        MinX = x - radius,
        MaxX = x + radius,
    }
end

function Broadphase:FindPairs(world)
    local ids = world:GetEntityIds()
    local proxies = {}

    for index = 1, #ids do
        local entityId = ids[index]
        local entity = world:GetEntity(entityId)
        local bounds = world:GetComponent(entityId, "Bounds")
        if entity and type(bounds) == "table" and type(bounds.Radius) == "number" then
            proxies[#proxies + 1] = makeProxy(entityId, entity, bounds)
        end
    end

    table.sort(proxies, function(a, b)
        if a.MinX ~= b.MinX then
            return a.MinX < b.MinX
        end
        return a.EntityId < b.EntityId
    end)

    local active = {}
    local pairsOut = {}
    local tests = 0

    for index = 1, #proxies do
        local proxy = proxies[index]

        for activeIndex = #active, 1, -1 do
            if active[activeIndex].MaxX < proxy.MinX then
                table.remove(active, activeIndex)
            end
        end

        for activeIndex = 1, #active do
            local other = active[activeIndex]
            tests += 1
            local a = other.EntityId
            local b = proxy.EntityId
            if a > b then
                a, b = b, a
            end
            pairsOut[#pairsOut + 1] = { A = a, B = b }
        end

        active[#active + 1] = proxy
        table.sort(active, function(a, b)
            if a.MaxX ~= b.MaxX then
                return a.MaxX < b.MaxX
            end
            return a.EntityId < b.EntityId
        end)
    end

    table.sort(pairsOut, function(a, b)
        if a.A ~= b.A then
            return a.A < b.A
        end
        return a.B < b.B
    end)

    return {
        Pairs = pairsOut,
        ProxyCount = #proxies,
        PairCount = #pairsOut,
        TestCount = tests,
    }
end

return Broadphase
