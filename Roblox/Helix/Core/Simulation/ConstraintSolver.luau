local ConstraintSolver = {}

local function safeNumber(value, fallback)
    if type(value) == "number" then
        if value == value and value ~= math.huge and value ~= -math.huge then
            return value
        end
    end
    return fallback
end

local function distance(x, y, z)
    local mag2 = x * x + y * y + z * z
    if mag2 <= 0 then
        return 0
    end
    return math.sqrt(mag2)
end

local function solveDistance(world, aId, bId, restLength, stiffness, damping)
    local aEntity = world:GetEntity(aId)
    local bEntity = world:GetEntity(bId)
    if not aEntity or not bEntity then
        return false
    end

    local ax = aEntity.LocalTransform.X or 0
    local ay = aEntity.LocalTransform.Y or 0
    local az = aEntity.LocalTransform.Z or 0
    local bx = bEntity.LocalTransform.X or 0
    local by = bEntity.LocalTransform.Y or 0
    local bz = bEntity.LocalTransform.Z or 0

    local dx = bx - ax
    local dy = by - ay
    local dz = bz - az
    local current = distance(dx, dy, dz)
    if current <= 0.000001 then
        return false
    end

    local error = current - restLength
    if math.abs(error) <= 0.000001 then
        return false
    end

    local nx = dx / current
    local ny = dy / current
    local nz = dz / current

    local aBody = world:GetComponent(aId, "Body")
    local bBody = world:GetComponent(bId, "Body")
    local aDynamic = aBody and aBody.Dynamic == true
    local bDynamic = bBody and bBody.Dynamic == true
    local aInvMass = aDynamic and 1 / math.max(0.0001, safeNumber(aBody.Mass, 1)) or 0
    local bInvMass = bDynamic and 1 / math.max(0.0001, safeNumber(bBody.Mass, 1)) or 0
    local invMassSum = aInvMass + bInvMass
    if invMassSum <= 0 then
        return false
    end

    local correction = error * stiffness
    local aMove = correction * (aInvMass / invMassSum)
    local bMove = correction * (bInvMass / invMassSum)

    if aDynamic then
        world:SetLocalTransform(aId, ax + nx * aMove, ay + ny * aMove, az + nz * aMove)
    end
    if bDynamic then
        world:SetLocalTransform(bId, bx - nx * bMove, by - ny * bMove, bz - nz * bMove)
    end

    if damping > 0 then
        local avx = safeNumber(aBody and aBody.VX, 0)
        local avy = safeNumber(aBody and aBody.VY, 0)
        local avz = safeNumber(aBody and aBody.VZ, 0)
        local bvx = safeNumber(bBody and bBody.VX, 0)
        local bvy = safeNumber(bBody and bBody.VY, 0)
        local bvz = safeNumber(bBody and bBody.VZ, 0)
        local relVx = bvx - avx
        local relVy = bvy - avy
        local relVz = bvz - avz
        local relNormal = relVx * nx + relVy * ny + relVz * nz
        local dv = relNormal * damping

        if aDynamic and aBody then
            aBody.VX = avx + nx * dv * (aInvMass / invMassSum)
            aBody.VY = avy + ny * dv * (aInvMass / invMassSum)
            aBody.VZ = avz + nz * dv * (aInvMass / invMassSum)
        end
        if bDynamic and bBody then
            bBody.VX = bvx - nx * dv * (bInvMass / invMassSum)
            bBody.VY = bvy - ny * dv * (bInvMass / invMassSum)
            bBody.VZ = bvz - nz * dv * (bInvMass / invMassSum)
        end
    end

    return true
end

function ConstraintSolver:Solve(world, config)
    local iterations = math.max(1, math.floor(safeNumber(config and config.ConstraintIterations, 4)))
    local ids = world:GetEntityIds()
    local solved = 0

    for _ = 1, iterations do
        for index = 1, #ids do
            local entityId = ids[index]
            local constraint = world:GetComponent(entityId, "Constraint")
            if type(constraint) == "table" and constraint.Type == "Distance" then
                local targetId = constraint.Target
                if type(targetId) == "number" and entityId < targetId then
                    local restLength = safeNumber(constraint.RestLength, 0)
                    local stiffness = math.max(0, math.min(1, safeNumber(constraint.Stiffness, 1)))
                    local damping = math.max(0, math.min(1, safeNumber(constraint.Damping, 0.1)))
                    if solveDistance(world, entityId, targetId, restLength, stiffness, damping) then
                        solved += 1
                    end
                end
            end
        end
    end

    return solved
end

return ConstraintSolver
