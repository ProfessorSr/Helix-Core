local ContentValidator = {}

local function isFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function sanitizeVec3(value)
    if type(value) ~= "table" then
        return nil
    end
    local x = isFiniteNumber(value.X) and value.X or 0
    local y = isFiniteNumber(value.Y) and value.Y or 0
    local z = isFiniteNumber(value.Z) and value.Z or 0
    return { X = x, Y = y, Z = z }
end

local function sanitizeBody(value)
    if type(value) ~= "table" then
        return nil
    end
    return {
        Dynamic = value.Dynamic == true,
        Mass = clamp(isFiniteNumber(value.Mass) and value.Mass or 1, 0.0001, 100000),
        VX = isFiniteNumber(value.VX) and value.VX or 0,
        VY = isFiniteNumber(value.VY) and value.VY or 0,
        VZ = isFiniteNumber(value.VZ) and value.VZ or 0,
        LinearDamping = clamp(isFiniteNumber(value.LinearDamping) and value.LinearDamping or 0, 0, 10),
        Restitution = clamp(isFiniteNumber(value.Restitution) and value.Restitution or 0.1, 0, 1),
        Friction = clamp(isFiniteNumber(value.Friction) and value.Friction or 0.2, 0, 1),
        GravityScale = clamp(isFiniteNumber(value.GravityScale) and value.GravityScale or 1, -10, 10),
    }
end

local function sanitizeBounds(value)
    if type(value) ~= "table" then
        return nil
    end
    return {
        Radius = clamp(isFiniteNumber(value.Radius) and value.Radius or 1, 0.0001, 100000),
    }
end

local function sanitizeConstraint(value)
    if type(value) ~= "table" then
        return nil
    end
    if value.Type ~= "Distance" then
        return nil
    end
    if type(value.Target) ~= "number" then
        return nil
    end
    return {
        Type = "Distance",
        Target = math.floor(value.Target),
        RestLength = isFiniteNumber(value.RestLength) and math.max(0, value.RestLength) or 0,
        Stiffness = clamp(isFiniteNumber(value.Stiffness) and value.Stiffness or 1, 0, 1),
        Damping = clamp(isFiniteNumber(value.Damping) and value.Damping or 0.1, 0, 1),
    }
end

function ContentValidator:SanitizeComponent(componentName, value)
    if componentName == "Body" then
        return sanitizeBody(value)
    end
    if componentName == "Bounds" then
        return sanitizeBounds(value)
    end
    if componentName == "Constraint" then
        return sanitizeConstraint(value)
    end
    return value
end

function ContentValidator:SanitizeEntityInitial(initial)
    if type(initial) ~= "table" then
        return nil
    end

    local out = {}
    local localTransform = sanitizeVec3(initial.LocalTransform)
    if localTransform then
        out.LocalTransform = localTransform
    end

    if type(initial.Components) == "table" then
        out.Components = {}
        for key, value in pairs(initial.Components) do
            if type(key) == "string" then
                out.Components[key] = self:SanitizeComponent(key, value)
            end
        end
    end

    return out
end

return ContentValidator
