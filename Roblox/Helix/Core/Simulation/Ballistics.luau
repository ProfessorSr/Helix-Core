local Workspace = game:GetService("Workspace")

local Ballistics = {}
Ballistics.__index = Ballistics

local function safeNumber(value, fallback)
    if type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge then
        return value
    end
    return fallback
end

local function safeVector(value, fallback)
    if typeof(value) == "Vector3" then
        return value
    end
    return fallback
end

local function normalizeOrZero(v)
    local m = v.Magnitude
    if m <= 1e-9 then
        return Vector3.zero
    end
    return v / m
end

function Ballistics.new()
    local self = setmetatable({}, Ballistics)
    self._pools = {}
    self._nextBulletId = 0
    self._stats = {
        Pools = 0,
        Active = 0,
        Free = 0,
        Fired = 0,
        Hits = 0,
        Misses = 0,
    }
    return self
end

local function updateStats(self)
    local pools = 0
    local active = 0
    local free = 0
    for _, pool in pairs(self._pools) do
        pools += 1
        active += #pool.Active
        free += #pool.Free
    end
    self._stats.Pools = pools
    self._stats.Active = active
    self._stats.Free = free
end

function Ballistics:CreatePool(poolId, options)
    if type(poolId) ~= "string" or poolId == "" then
        return false, "invalid_pool_id"
    end

    local opts = type(options) == "table" and options or {}
    local pool = self._pools[poolId]
    if not pool then
        pool = {
            Id = poolId,
            Capacity = math.max(1, math.floor(safeNumber(opts.Capacity, 256))),
            Defaults = {
                Speed = math.max(0.001, safeNumber(opts.Speed, 2000)),
                MaxDistance = math.max(0.1, safeNumber(opts.MaxDistance, 4000)),
                StepDistance = math.max(0.01, safeNumber(opts.StepDistance, 2.0)),
                Gravity = safeVector(opts.Gravity, Vector3.new(0, -Workspace.Gravity, 0)),
                MaxTime = math.max(0.01, safeNumber(opts.MaxTime, 10.0)),
            },
            Free = {},
            Active = {},
        }
        self._pools[poolId] = pool
    else
        pool.Capacity = math.max(1, math.floor(safeNumber(opts.Capacity, pool.Capacity)))
        pool.Defaults.Speed = math.max(0.001, safeNumber(opts.Speed, pool.Defaults.Speed))
        pool.Defaults.MaxDistance = math.max(0.1, safeNumber(opts.MaxDistance, pool.Defaults.MaxDistance))
        pool.Defaults.StepDistance = math.max(0.01, safeNumber(opts.StepDistance, pool.Defaults.StepDistance))
        pool.Defaults.Gravity = safeVector(opts.Gravity, pool.Defaults.Gravity)
        pool.Defaults.MaxTime = math.max(0.01, safeNumber(opts.MaxTime, pool.Defaults.MaxTime))
    end

    updateStats(self)
    return true
end

function Ballistics:DestroyPool(poolId)
    self._pools[poolId] = nil
    updateStats(self)
    return true
end

local function acquireBullet(self, pool)
    local bullet = table.remove(pool.Free)
    if bullet then
        return bullet
    end

    if (#pool.Free + #pool.Active) >= pool.Capacity then
        bullet = table.remove(pool.Active, 1)
        if bullet then
            bullet.Active = false
            return bullet
        end
    end

    self._nextBulletId += 1
    return {
        Id = self._nextBulletId,
    }
end

local function releaseBullet(pool, bullet)
    bullet.Active = false
    bullet.Origin = nil
    bullet.Direction = nil
    bullet.Position = nil
    bullet.Velocity = nil
    bullet.Acceleration = nil
    bullet.RayParams = nil
    bullet.Distance = 0
    bullet.Time = 0
    bullet.Steps = 0
    table.insert(pool.Free, bullet)
end

function Ballistics:Fire(poolId, request)
    local pool = self._pools[poolId]
    if not pool then
        return nil, "pool_not_found"
    end

    local req = type(request) == "table" and request or {}
    local origin = safeVector(req.Origin, nil)
    if not origin then
        return nil, "missing_origin"
    end

    local direction = normalizeOrZero(safeVector(req.Direction, Vector3.new(0, -1, 0)))
    if direction.Magnitude <= 0 then
        return nil, "invalid_direction"
    end

    local speed = math.max(0.001, safeNumber(req.Speed, pool.Defaults.Speed))
    local maxDistance = math.max(0.1, safeNumber(req.MaxDistance, pool.Defaults.MaxDistance))
    local stepDistance = math.max(0.01, safeNumber(req.StepDistance, pool.Defaults.StepDistance))
    local maxTime = math.max(0.01, safeNumber(req.MaxTime, pool.Defaults.MaxTime))
    local gravity = safeVector(req.Gravity, pool.Defaults.Gravity)
    local extraAccel = safeVector(req.Acceleration, Vector3.zero)
    local acceleration = gravity + extraAccel
    local rayParams = req.RaycastParams

    local bullet = acquireBullet(self, pool)
    bullet.Active = true
    bullet.Origin = origin
    bullet.Direction = direction
    bullet.Position = origin
    bullet.Velocity = direction * speed
    bullet.Acceleration = acceleration
    bullet.RayParams = rayParams
    bullet.Distance = 0
    bullet.Time = 0
    bullet.Steps = 0
    table.insert(pool.Active, bullet)

    local position = bullet.Position
    local velocity = bullet.Velocity
    local traveled = 0
    local elapsed = 0
    local steps = 0

    while traveled < maxDistance and elapsed < maxTime do
        local dt = stepDistance / math.max(0.001, velocity.Magnitude)
        local nextPosition = position + velocity * dt + acceleration * (0.5 * dt * dt)
        local segment = nextPosition - position
        local segmentLength = segment.Magnitude

        if segmentLength > 0 then
            local hit = Workspace:Raycast(position, segment, rayParams)
            if hit then
                self._stats.Fired += 1
                self._stats.Hits += 1
                for i = #pool.Active, 1, -1 do
                    if pool.Active[i] == bullet then
                        table.remove(pool.Active, i)
                        break
                    end
                end
                releaseBullet(pool, bullet)
                updateStats(self)
                return {
                    Hit = true,
                    BulletId = bullet.Id,
                    PoolId = poolId,
                    Position = hit.Position,
                    Normal = hit.Normal,
                    Instance = hit.Instance,
                    Material = hit.Material,
                    Distance = traveled + (hit.Position - position).Magnitude,
                    Time = elapsed,
                    Steps = steps + 1,
                }
            end
        end

        position = nextPosition
        velocity = velocity + acceleration * dt
        traveled += segmentLength
        elapsed += dt
        steps += 1
    end

    self._stats.Fired += 1
    self._stats.Misses += 1
    for i = #pool.Active, 1, -1 do
        if pool.Active[i] == bullet then
            table.remove(pool.Active, i)
            break
        end
    end
    releaseBullet(pool, bullet)
    updateStats(self)
    return {
        Hit = false,
        BulletId = bullet.Id,
        PoolId = poolId,
        Position = position,
        Normal = nil,
        Instance = nil,
        Material = nil,
        Distance = traveled,
        Time = elapsed,
        Steps = steps,
    }
end

function Ballistics:GetStats()
    updateStats(self)
    local out = {}
    for k, v in pairs(self._stats) do
        out[k] = v
    end
    return out
end

return Ballistics
