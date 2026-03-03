local PhysicsPipeline = {}
PhysicsPipeline.__index = PhysicsPipeline

local Broadphase = require(script.Parent:WaitForChild("Broadphase"))
local ConstraintSolver = require(script.Parent:WaitForChild("ConstraintSolver"))
local SnapshotDiff = require(script.Parent:WaitForChild("SnapshotDiff"))

local function copyTable(input)
    local out = {}
    if type(input) ~= "table" then
        return out
    end
    for key, value in pairs(input) do
        out[key] = value
    end
    return out
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

local function deterministicWorldHash(world)
    local ids = world:GetEntityIds()
    local acc = 2166136261

    for index = 1, #ids do
        local entityId = ids[index]
        local entity = world:GetEntity(entityId)
        if entity then
            local worldTransform = entity.WorldTransform or {}
            local x = math.floor((worldTransform.X or 0) * 1000)
            local y = math.floor((worldTransform.Y or 0) * 1000)
            local z = math.floor((worldTransform.Z or 0) * 1000)

            local body = world:GetComponent(entityId, "Body")
            local vx = math.floor(((body and body.VX) or 0) * 1000)
            local vy = math.floor(((body and body.VY) or 0) * 1000)
            local vz = math.floor(((body and body.VZ) or 0) * 1000)

            acc = bit32.bxor(acc, entityId)
            acc = (acc * 16777619) % 4294967296
            acc = bit32.bxor(acc, x)
            acc = (acc * 16777619) % 4294967296
            acc = bit32.bxor(acc, y)
            acc = (acc * 16777619) % 4294967296
            acc = bit32.bxor(acc, z)
            acc = (acc * 16777619) % 4294967296
            acc = bit32.bxor(acc, vx)
            acc = (acc * 16777619) % 4294967296
            acc = bit32.bxor(acc, vy)
            acc = (acc * 16777619) % 4294967296
            acc = bit32.bxor(acc, vz)
            acc = (acc * 16777619) % 4294967296
        end
    end

    return string.format("%08x", acc)
end

local function normalizeCollisions(input)
    local merged = {}
    local out = {}
    for index = 1, #input do
        local entry = input[index]
        local a = math.floor(tonumber(entry.A) or 0)
        local b = math.floor(tonumber(entry.B) or 0)
        if a > b then
            a, b = b, a
        end
        local key = string.format("%d:%d", a, b)
        local existing = merged[key]
        if not existing then
            merged[key] = {
                A = a,
                B = b,
                Penetration = entry.Penetration or 0,
                Correction = entry.Correction or 0,
            }
        else
            existing.Penetration = math.max(existing.Penetration, entry.Penetration or 0)
            existing.Correction = math.max(existing.Correction, entry.Correction or 0)
        end
    end

    for _, value in pairs(merged) do
        out[#out + 1] = value
    end
    table.sort(out, function(a, b)
        if a.A ~= b.A then
            return a.A < b.A
        end
        return a.B < b.B
    end)
    return out
end

local DEFAULT_CONFIG = {
    FixedStep = 1 / 60,
    MaxSubsteps = 4,
    MaxFrameTime = 1 / 10,
    Gravity = 196.2,
    RewindCaptureInterval = 1,
    ConstraintIterations = 4,
    CollisionIterations = 2,
    MaxCollisionRecordsPerStep = 512,
    CaptureStateDiff = true,
}

function PhysicsPipeline.new(config)
    local merged = copyTable(DEFAULT_CONFIG)
    for key, value in pairs(copyTable(config)) do
        merged[key] = value
    end

    merged.FixedStep = math.max(1 / 240, tonumber(merged.FixedStep) or DEFAULT_CONFIG.FixedStep)
    merged.MaxSubsteps = math.max(1, math.floor(tonumber(merged.MaxSubsteps) or DEFAULT_CONFIG.MaxSubsteps))
    merged.MaxFrameTime = math.max(merged.FixedStep, tonumber(merged.MaxFrameTime) or DEFAULT_CONFIG.MaxFrameTime)
    merged.RewindCaptureInterval = math.max(1, math.floor(tonumber(merged.RewindCaptureInterval) or DEFAULT_CONFIG.RewindCaptureInterval))

    return setmetatable({
        Config = merged,
        Accumulator = 0,
        SimulationTick = 0,
        LastSnapshot = nil,
    }, PhysicsPipeline)
end

function PhysicsPipeline:Configure(config)
    if type(config) ~= "table" then
        return
    end

    for key, value in pairs(config) do
        self.Config[key] = value
    end

    self.Config.FixedStep = math.max(1 / 240, tonumber(self.Config.FixedStep) or DEFAULT_CONFIG.FixedStep)
    self.Config.MaxSubsteps = math.max(1, math.floor(tonumber(self.Config.MaxSubsteps) or DEFAULT_CONFIG.MaxSubsteps))
    self.Config.MaxFrameTime = math.max(self.Config.FixedStep, tonumber(self.Config.MaxFrameTime) or DEFAULT_CONFIG.MaxFrameTime)
    self.Config.RewindCaptureInterval = math.max(1, math.floor(tonumber(self.Config.RewindCaptureInterval) or DEFAULT_CONFIG.RewindCaptureInterval))
end

function PhysicsPipeline:ComputeStateHash(world)
    return deterministicWorldHash(world)
end

function PhysicsPipeline:Step(simulation, dt, kernel)
    local world = simulation and simulation.World
    local collision = simulation and simulation.Collision
    local spatial = simulation and simulation.Spatial
    if not world or not collision or not spatial then
        return nil
    end

    local stepDt = self.Config.FixedStep
    local scaledDt = clamp((dt or 0) * (simulation.TimeScale or 1), 0, self.Config.MaxFrameTime)
    self.Accumulator += scaledDt

    local processedSubsteps = 0
    local lastCollisions = simulation.LastCollisions or {}
    local lastBroadphase = simulation.LastBroadphase or { ProxyCount = 0, PairCount = 0, TestCount = 0 }
    local lastConstraintsSolved = 0
    local lastDiff = simulation.LastStateDiff or nil

    while self.Accumulator >= stepDt and processedSubsteps < self.Config.MaxSubsteps do
        self.SimulationTick += 1

        local lockstep = simulation.Lockstep
        if lockstep and lockstep.ConsumeTick then
            simulation.LastLockstepInputs = lockstep:ConsumeTick(self.SimulationTick)
        end

        local previousSnapshot = world.CloneState and world:CloneState() or nil

        collision:Integrate(world, stepDt, self.Config.Gravity, self.Config)
        spatial:Propagate(world)
        local collisionIterations = math.max(1, math.floor(tonumber(self.Config.CollisionIterations) or 2))
        local accumulatedCollisions = {}
        lastConstraintsSolved = 0
        for _ = 1, collisionIterations do
            lastBroadphase = Broadphase:FindPairs(world)
            local resolveConfig = copyTable(self.Config)
            resolveConfig.Candidates = lastBroadphase.Pairs
            local iterationCollisions = collision:Resolve(world, resolveConfig)
            for cIndex = 1, #iterationCollisions do
                accumulatedCollisions[#accumulatedCollisions + 1] = iterationCollisions[cIndex]
            end
            local solvedThisPass = ConstraintSolver:Solve(world, self.Config)
            lastConstraintsSolved += solvedThisPass
            spatial:Propagate(world)
        end
        lastCollisions = normalizeCollisions(accumulatedCollisions)
        local maxRecords = math.max(1, math.floor(tonumber(self.Config.MaxCollisionRecordsPerStep) or 512))
        while #lastCollisions > maxRecords do
            table.remove(lastCollisions)
        end

        world.Tick = self.SimulationTick
        simulation.LastPhysicsTick = self.SimulationTick
        simulation.LastCollisions = lastCollisions
        simulation.LastBroadphase = lastBroadphase
        simulation.LastConstraintsSolved = lastConstraintsSolved
        simulation.LastStateHash = self:ComputeStateHash(world)

        local currentSnapshot = world.CloneState and world:CloneState() or nil
        if self.Config.CaptureStateDiff ~= false and previousSnapshot and currentSnapshot then
            lastDiff = SnapshotDiff:DiffStates(previousSnapshot, currentSnapshot)
            simulation.LastStateDiff = lastDiff
            self.LastSnapshot = currentSnapshot
        elseif self.Config.CaptureStateDiff == false then
            simulation.LastStateDiff = nil
        end

        local rewind = simulation.Rewind
        if rewind and rewind.Capture and world.CloneState then
            if self.SimulationTick % self.Config.RewindCaptureInterval == 0 then
                rewind:Capture(self.SimulationTick, world:CloneState())
            end
        end

        local eventAuthority = kernel and kernel.EventAuthority
        if eventAuthority and eventAuthority.Publish and #lastCollisions > 0 then
            eventAuthority:Publish("Physics.CollisionsResolved", {
                Tick = self.SimulationTick,
                Count = #lastCollisions,
                Pairs = lastCollisions,
                BroadphasePairs = lastBroadphase.PairCount,
                ConstraintSolves = lastConstraintsSolved,
            })
        end

        self.Accumulator -= stepDt
        processedSubsteps += 1
    end

    local droppedFrameTime = false
    if processedSubsteps == self.Config.MaxSubsteps and self.Accumulator >= stepDt then
        self.Accumulator = 0
        droppedFrameTime = true
    end

    return {
        StepDt = stepDt,
        ProcessedSubsteps = processedSubsteps,
        DroppedFrameTime = droppedFrameTime,
        Tick = self.SimulationTick,
        CollisionCount = #lastCollisions,
        Collisions = lastCollisions,
        Broadphase = lastBroadphase,
        ConstraintSolves = lastConstraintsSolved,
        StateDiff = lastDiff,
        StateHash = simulation.LastStateHash,
    }
end

return PhysicsPipeline
