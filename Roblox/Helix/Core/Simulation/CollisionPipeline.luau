local CollisionPipeline = {}

local function lengthSquared(x, y, z)
    return x * x + y * y + z * z
end

local function normalize(x, y, z)
    local mag2 = lengthSquared(x, y, z)
    if mag2 <= 0 then
        return 0, 1, 0
    end
    local mag = math.sqrt(mag2)
    return x / mag, y / mag, z / mag
end

local function safeNumber(value, fallback)
    if type(value) == "number" then
        if value == value and value ~= math.huge and value ~= -math.huge then
            return value
        end
    end
    return fallback
end

local function ensureForce(body)
    local force = body.Force
    if type(force) ~= "table" then
        force = { X = 0, Y = 0, Z = 0 }
        body.Force = force
    end

    force.X = safeNumber(force.X, 0)
    force.Y = safeNumber(force.Y, 0)
    force.Z = safeNumber(force.Z, 0)

    return force
end

function CollisionPipeline:Integrate(world, dt, gravity, config)
    local gravityValue = safeNumber(gravity, 196.2)
    local maxSpeed = safeNumber(config and config.MaxSpeed, 2048)
    local sleepVelocity = safeNumber(config and config.SleepVelocity, 0.01)
    local sleepFrames = math.max(1, math.floor(safeNumber(config and config.SleepFrames, 30)))
    local entityIds = world:GetEntityIds()
    for index = 1, #entityIds do
        local entityId = entityIds[index]
        local body = world:GetComponent(entityId, "Body")
        if body and body.Dynamic == true then
            local mass = math.max(0.0001, safeNumber(body.Mass, 1))
            local invMass = 1 / mass
            local drag = math.max(0, safeNumber(body.LinearDamping, 0))
            local gravityScale = safeNumber(body.GravityScale, 1)
            local force = ensureForce(body)

            local ax = force.X * invMass
            local ay = (force.Y * invMass) - gravityValue * gravityScale
            local az = force.Z * invMass

            local dampingFactor = math.max(0, 1 - drag * dt)
            body.VX = (safeNumber(body.VX, 0) + ax * dt) * dampingFactor
            body.VY = (safeNumber(body.VY, 0) + ay * dt) * dampingFactor
            body.VZ = (safeNumber(body.VZ, 0) + az * dt) * dampingFactor

            body.VX = math.clamp(body.VX, -maxSpeed, maxSpeed)
            body.VY = math.clamp(body.VY, -maxSpeed, maxSpeed)
            body.VZ = math.clamp(body.VZ, -maxSpeed, maxSpeed)

            local speed2 = lengthSquared(body.VX, body.VY, body.VZ)
            if speed2 <= (sleepVelocity * sleepVelocity) then
                body.SleepCounter = (body.SleepCounter or 0) + 1
                if body.SleepCounter >= sleepFrames then
                    body.VX = 0
                    body.VY = 0
                    body.VZ = 0
                end
            else
                body.SleepCounter = 0
            end

            force.X = 0
            force.Y = 0
            force.Z = 0

            local localTransform = world:GetEntity(entityId).LocalTransform
            world:SetLocalTransform(
                entityId,
                (localTransform.X or 0) + (body.VX or 0) * dt,
                (localTransform.Y or 0) + (body.VY or 0) * dt,
                (localTransform.Z or 0) + (body.VZ or 0) * dt
            )
        end
    end
end

local function resolveGround(world, entityId, entity, body, bounds, config)
    if not body or not body.Dynamic then
        return nil
    end

    local groundY = safeNumber(config and config.GroundY, 0)
    local radius = safeNumber(bounds and bounds.Radius, 0)
    local restitution = math.max(0, math.min(1, safeNumber(body.Restitution, safeNumber(config and config.DefaultRestitution, 0.1))))
    local friction = math.max(0, math.min(1, safeNumber(body.Friction, safeNumber(config and config.DefaultFriction, 0.2))))
    local y = (entity.LocalTransform and entity.LocalTransform.Y) or 0
    local bottomY = y - radius

    if bottomY >= groundY then
        return nil
    end

    local correctedY = groundY + radius
    world:SetLocalTransform(
        entityId,
        entity.LocalTransform.X or 0,
        correctedY,
        entity.LocalTransform.Z or 0
    )

    local vy = safeNumber(body.VY, 0)
    if vy < 0 then
        body.VY = -vy * restitution
        body.VX = (body.VX or 0) * (1 - friction)
        body.VZ = (body.VZ or 0) * (1 - friction)
        body.SleepCounter = 0
    end

    return {
        A = entityId,
        B = 0,
        Penetration = groundY - bottomY,
        Correction = groundY - bottomY,
    }
end

function CollisionPipeline:Resolve(world, config)
    local collisions = {}
    local entityIds = world:GetEntityIds()
    local slop = math.max(0, safeNumber(config and config.PenetrationSlop, 0.001))
    local baumgarte = math.max(0, math.min(1, safeNumber(config and config.Baumgarte, 0.25)))
    local maxCorrection = math.max(0, safeNumber(config and config.MaxCorrection, 1.0))

    -- Ground-plane solve first for stable contact.
    for index = 1, #entityIds do
        local entityId = entityIds[index]
        local entity = world:GetEntity(entityId)
        local body = world:GetComponent(entityId, "Body")
        local bounds = world:GetComponent(entityId, "Bounds")
        if entity then
            local groundCollision = resolveGround(world, entityId, entity, body, bounds, config)
            if groundCollision then
                collisions[#collisions + 1] = groundCollision
            end
        end
    end

    local function resolvePair(aId, bId)
        local aEntity = world:GetEntity(aId)
        local bEntity = world:GetEntity(bId)
        local aBounds = world:GetComponent(aId, "Bounds")
        local bBounds = world:GetComponent(bId, "Bounds")
        if not (aEntity and bEntity and aBounds and bBounds) then
            return
        end
        if type(aBounds.Radius) ~= "number" or type(bBounds.Radius) ~= "number" then
            return
        end

        local dx = (bEntity.WorldTransform.X or 0) - (aEntity.WorldTransform.X or 0)
        local dy = (bEntity.WorldTransform.Y or 0) - (aEntity.WorldTransform.Y or 0)
        local dz = (bEntity.WorldTransform.Z or 0) - (aEntity.WorldTransform.Z or 0)
        local dist2 = lengthSquared(dx, dy, dz)
        local minDist = aBounds.Radius + bBounds.Radius
        if dist2 >= (minDist * minDist) then
            return
        end

        local nx, ny, nz = normalize(dx, dy, dz)
        local dist = math.sqrt(math.max(dist2, 0.00001))
        local penetration = math.max(0, minDist - dist)
        local correctedPenetration = math.clamp((penetration - slop) * baumgarte, 0, maxCorrection)
        if correctedPenetration <= 0 then
            return
        end
        local aBody = world:GetComponent(aId, "Body")
        local bBody = world:GetComponent(bId, "Body")
        local aDynamic = aBody and aBody.Dynamic == true
        local bDynamic = bBody and bBody.Dynamic == true
        local aInvMass = aDynamic and 1 / math.max(0.0001, safeNumber(aBody.Mass, 1)) or 0
        local bInvMass = bDynamic and 1 / math.max(0.0001, safeNumber(bBody.Mass, 1)) or 0
        local invMassSum = math.max(0.0001, aInvMass + bInvMass)
        local aMove = aInvMass / invMassSum
        local bMove = bInvMass / invMassSum

        local aLocal = aEntity.LocalTransform
        local bLocal = bEntity.LocalTransform
        world:SetLocalTransform(aId, (aLocal.X or 0) - nx * (correctedPenetration * aMove), (aLocal.Y or 0) - ny * (correctedPenetration * aMove), (aLocal.Z or 0) - nz * (correctedPenetration * aMove))
        world:SetLocalTransform(bId, (bLocal.X or 0) + nx * (correctedPenetration * bMove), (bLocal.Y or 0) + ny * (correctedPenetration * bMove), (bLocal.Z or 0) + nz * (correctedPenetration * bMove))

        if aDynamic or bDynamic then
            local avx = (aBody and aBody.VX) or 0
            local avy = (aBody and aBody.VY) or 0
            local avz = (aBody and aBody.VZ) or 0
            local bvx = (bBody and bBody.VX) or 0
            local bvy = (bBody and bBody.VY) or 0
            local bvz = (bBody and bBody.VZ) or 0
            local rvx = bvx - avx
            local rvy = bvy - avy
            local rvz = bvz - avz
            local normalSpeed = rvx * nx + rvy * ny + rvz * nz
            if normalSpeed < 0 then
                local aRestitution = safeNumber(aBody and aBody.Restitution, safeNumber(config and config.DefaultRestitution, 0.1))
                local bRestitution = safeNumber(bBody and bBody.Restitution, safeNumber(config and config.DefaultRestitution, 0.1))
                local restitution = math.max(0, math.min(1, math.min(aRestitution, bRestitution)))
                local impulse = -(1 + restitution) * normalSpeed / invMassSum
                local ix = impulse * nx
                local iy = impulse * ny
                local iz = impulse * nz
                if aDynamic then
                    aBody.VX = avx - ix * aInvMass
                    aBody.VY = avy - iy * aInvMass
                    aBody.VZ = avz - iz * aInvMass
                end
                if bDynamic then
                    bBody.VX = bvx + ix * bInvMass
                    bBody.VY = bvy + iy * bInvMass
                    bBody.VZ = bvz + iz * bInvMass
                end
            end
        end

        local outA = aId
        local outB = bId
        if outA > outB then
            outA, outB = outB, outA
        end
        collisions[#collisions + 1] = {
            A = outA,
            B = outB,
            Penetration = penetration,
            Correction = correctedPenetration,
        }
    end

    local candidates = config and config.Candidates
    if type(candidates) == "table" then
        for index = 1, #candidates do
            local candidate = candidates[index]
            if candidate and type(candidate.A) == "number" and type(candidate.B) == "number" then
                resolvePair(candidate.A, candidate.B)
            end
        end
    else
        for i = 1, #entityIds do
            local aId = entityIds[i]
            for j = i + 1, #entityIds do
                resolvePair(aId, entityIds[j])
            end
        end
    end

    table.sort(collisions, function(a, b)
        if a.A ~= b.A then
            return a.A < b.A
        end
        return a.B < b.B
    end)

    return collisions
end

return CollisionPipeline
