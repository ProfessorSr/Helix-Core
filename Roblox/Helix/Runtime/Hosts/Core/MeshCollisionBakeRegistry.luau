local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshCollisionBakeRegistry = {}

local _loaded = false
local _byMeshKey = {}
local _candidateCount = 0
local _moduleCount = 0
local _entryCount = 0
local _warnedEmpty = false

local function normalizeMeshKey(value)
    if type(value) ~= "string" then
        return nil
    end
    local raw = string.lower(string.gsub(value, "%s+", ""))
    if raw == "" then
        return nil
    end

    -- Canonicalize common Roblox content id forms to bare numeric asset id.
    -- Examples:
    -- rbxassetid://123456
    -- http://www.roblox.com/asset/?id=123456
    -- 123456
    local numeric = string.match(raw, "id=(%d+)")
    if numeric then
        return numeric
    end
    numeric = string.match(raw, "rbxassetid://(%d+)")
    if numeric then
        return numeric
    end
    numeric = string.match(raw, "rbxasset://(%d+)")
    if numeric then
        return numeric
    end
    numeric = string.match(raw, "^(%d+)$")
    if numeric then
        return numeric
    end

    return raw
end

local function toNumber(value, fallback)
    local n = tonumber(value)
    if n == nil or n ~= n or n == math.huge or n == -math.huge then
        return fallback
    end
    return n
end

local function toRotation(input)
    if type(input) ~= "table" then
        return nil
    end
    return {
        X = toNumber(input.X or input.x or input.RX or input.rx, 0),
        Y = toNumber(input.Y or input.y or input.RY or input.ry, 0),
        Z = toNumber(input.Z or input.z or input.RZ or input.rz, 0),
    }
end

local function toHalfSize(input)
    if type(input) ~= "table" then
        return nil
    end
    return {
        X = math.max(0.0001, toNumber(input.X or input.x or input.HX or input.hx, 1)),
        Y = math.max(0.0001, toNumber(input.Y or input.y or input.HY or input.hy, 1)),
        Z = math.max(0.0001, toNumber(input.Z or input.z or input.HZ or input.hz, 1)),
    }
end

local function sanitizeChild(input)
    if type(input) ~= "table" then
        return nil
    end
    local shape = tostring(input.Shape or input.shape or "Box")
    local px = toNumber(input.PX or input.px, 0)
    local py = toNumber(input.PY or input.py, 0)
    local pz = toNumber(input.PZ or input.pz, 0)

    if shape == "Sphere" or shape == "sphere" then
        return {
            Shape = "Sphere",
            PX = px,
            PY = py,
            PZ = pz,
            Radius = math.max(0.0001, toNumber(input.Radius or input.radius or input.R or input.r, 1)),
        }
    end

    if shape == "Cylinder" or shape == "cylinder" then
        return {
            Shape = "Cylinder",
            PX = px,
            PY = py,
            PZ = pz,
            Rotation = toRotation(input.Rotation or input.rotation),
            Radius = math.max(0.0001, toNumber(input.Radius or input.radius or input.R or input.r, 1)),
            HalfHeight = math.max(0.0001, toNumber(input.HalfHeight or input.halfHeight or input.HH or input.hh, 1)),
        }
    end

    return {
        Shape = "Box",
        PX = px,
        PY = py,
        PZ = pz,
        Rotation = toRotation(input.Rotation or input.rotation),
        HalfSize = toHalfSize(input.HalfSize or input.halfSize or input),
    }
end

local function toVec3(input)
    if type(input) ~= "table" then
        return nil
    end
    local x = toNumber(input.X or input.x, nil)
    local y = toNumber(input.Y or input.y, nil)
    local z = toNumber(input.Z or input.z, nil)
    if x == nil or y == nil or z == nil then
        return nil
    end
    return { X = x, Y = y, Z = z }
end

local function toTriangle(input, vertexCount)
    if type(input) ~= "table" then
        return nil
    end
    local a = math.floor(toNumber(input.A or input.a or input[1], -1))
    local b = math.floor(toNumber(input.B or input.b or input[2], -1))
    local c = math.floor(toNumber(input.C or input.c or input[3], -1))
    if a < 1 or b < 1 or c < 1 or a > vertexCount or b > vertexCount or c > vertexCount then
        return nil
    end
    if a == b or b == c or a == c then
        return nil
    end
    return { A = a, B = b, C = c }
end

local function sanitizeTriangleMesh(input)
    local verticesIn = input.Vertices or input.vertices
    local trianglesIn = input.Triangles or input.triangles or input.Indices or input.indices
    if type(verticesIn) ~= "table" or type(trianglesIn) ~= "table" then
        return nil
    end

    local vertices = {}
    for i = 1, #verticesIn do
        local v = toVec3(verticesIn[i])
        if v then
            vertices[#vertices + 1] = v
        end
    end
    if #vertices < 3 then
        return nil
    end

    local triangles = {}
    for i = 1, #trianglesIn do
        local tri = toTriangle(trianglesIn[i], #vertices)
        if tri then
            triangles[#triangles + 1] = tri
        end
    end
    if #triangles == 0 then
        return nil
    end

    return {
        Shape = "TriangleMesh",
        Rotation = toRotation(input.Rotation or input.rotation),
        Vertices = vertices,
        Triangles = triangles,
    }
end

local function sanitizeBounds(input)
    if type(input) ~= "table" then
        return nil
    end

    local shape = tostring(input.Shape or input.shape or "")
    if shape == "TriangleMesh" or shape == "trianglemesh" or shape == "MeshHull" or shape == "meshhull" or shape == "Mesh" or shape == "mesh" then
        return sanitizeTriangleMesh(input)
    end
    if shape == "Compound" or shape == "compound" then
        local childrenIn = input.Children or input.children
        if type(childrenIn) ~= "table" then
            return nil
        end
        local children = {}
        for i = 1, #childrenIn do
            local child = sanitizeChild(childrenIn[i])
            if child then
                children[#children + 1] = child
            end
        end
        if #children == 0 then
            return nil
        end
        return {
            Shape = "Compound",
            Rotation = toRotation(input.Rotation or input.rotation),
            Children = children,
        }
    end

    if shape == "Sphere" or shape == "sphere" then
        return {
            Shape = "Sphere",
            Radius = math.max(0.0001, toNumber(input.Radius or input.radius or input.R or input.r, 1)),
        }
    end

    if shape == "Cylinder" or shape == "cylinder" then
        return {
            Shape = "Cylinder",
            Radius = math.max(0.0001, toNumber(input.Radius or input.radius or input.R or input.r, 1)),
            HalfHeight = math.max(0.0001, toNumber(input.HalfHeight or input.halfHeight or input.HH or input.hh, 1)),
            Rotation = toRotation(input.Rotation or input.rotation),
        }
    end

    local hs = toHalfSize(input.HalfSize or input.halfSize or input)
    if hs then
        return {
            Shape = "Box",
            HalfSize = hs,
            Rotation = toRotation(input.Rotation or input.rotation),
        }
    end

    return nil
end

local function ingestEntry(entry)
    if type(entry) ~= "table" then
        return
    end
    local key = normalizeMeshKey(entry.MeshKey or entry.meshKey or entry.MeshId or entry.meshId or entry.Key or entry.key)
    if not key then
        return
    end
    local bounds = sanitizeBounds(entry.Collision or entry.Bounds or entry.collision or entry.bounds or entry)
    if not bounds then
        return
    end
    _byMeshKey[key] = bounds
    _entryCount += 1
end

local function ingestPayload(payload)
    if type(payload) ~= "table" then
        return
    end

    if type(payload.Meshes) == "table" then
        for meshKey, collision in pairs(payload.Meshes) do
            ingestEntry({
                MeshKey = meshKey,
                Collision = collision,
            })
        end
    end

    if type(payload.entries) == "table" then
        for i = 1, #payload.entries do
            ingestEntry(payload.entries[i])
        end
    end

    if type(payload.Entries) == "table" then
        for i = 1, #payload.Entries do
            ingestEntry(payload.Entries[i])
        end
    end

    -- Also support direct dictionary payloads:
    -- return {
    --   ["rbxassetid://123"] = { Shape = "Compound", ... },
    --   ["456"] = { Shape = "TriangleMesh", ... },
    -- }
    for key, value in pairs(payload) do
        if type(key) == "string" and type(value) == "table" then
            ingestEntry({
                MeshKey = key,
                Collision = value,
            })
        end
    end
end

local function tryRequire(moduleScript)
    _moduleCount += 1
    local ok, resolved = pcall(require, moduleScript)
    if ok then
        ingestPayload(resolved)
    end
end

local function loadIfNeeded()
    if _loaded then
        return
    end
    _loaded = true

    local candidates = {
        ServerStorage:FindFirstChild("HelixMeshCollisionBake"),
        ReplicatedStorage:FindFirstChild("HelixMeshCollisionBake"),
    }
    _candidateCount = #candidates

    for i = 1, #candidates do
        local candidate = candidates[i]
        if candidate and candidate:IsA("ModuleScript") then
            tryRequire(candidate)
        end
    end
end

function MeshCollisionBakeRegistry:GetBoundsForMeshId(meshId)
    loadIfNeeded()
    if not _warnedEmpty and _entryCount == 0 then
        _warnedEmpty = true
        warn(string.format(
            "[MeshCollisionBakeRegistry] No baked mesh collision entries loaded (candidates=%d modules=%d).",
            _candidateCount,
            _moduleCount
        ))
    end
    local key = normalizeMeshKey(tostring(meshId))
    if not key then
        return nil
    end
    return _byMeshKey[key]
end

function MeshCollisionBakeRegistry:GetBoundsForPart(part)
    if not part or not part:IsA("MeshPart") then
        return nil
    end
    local meshId = tostring(part.MeshId)
    if meshId == "" then
        return nil
    end
    return self:GetBoundsForMeshId(meshId)
end

return MeshCollisionBakeRegistry
