local PhysicsSubsystem = {}
local PhysicsPipeline = require(script.Parent.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("Simulation"):WaitForChild("PhysicsPipeline"))

local SOURCE_HOST = "Host"
local SOURCE_HELIX = "Helix"

PhysicsSubsystem.Reader = nil
PhysicsSubsystem.Writer = nil

local function normalizeSource(value)
    if value == SOURCE_HOST then
        return SOURCE_HOST
    end
    return SOURCE_HELIX
end

function PhysicsSubsystem:Init(kernel, reader, writer)
    self.Kernel = kernel
    self.Reader = reader
    self.Writer = writer

    local source = SOURCE_HELIX
    if kernel and kernel.Config and kernel.Config.Get then
        source = kernel.Config:Get("PhysicsControlSource") or kernel.Config:Get("DefaultSubsystemControlSource") or source
    end
    self.ControlSource = normalizeSource(source)

    local fixedStep = 1 / 60
    local maxSubsteps = 4
    local maxFrameTime = 1 / 10
    local gravity = 196.2
    local rewindCaptureInterval = 1
    local constraintIterations = 4
    local collisionIterations = 2
    local maxSpeed = 2048
    local maxCollisionRecordsPerStep = 512
    local captureStateDiff = true
    local penetrationSlop = 0.001
    local baumgarte = 0.25
    local maxCorrection = 1.0
    local sleepVelocity = 0.01
    local sleepFrames = 30

    if kernel and kernel.Config and kernel.Config.Get then
        fixedStep = kernel.Config:Get("PhysicsFixedStep") or fixedStep
        maxSubsteps = kernel.Config:Get("PhysicsMaxSubsteps") or maxSubsteps
        maxFrameTime = kernel.Config:Get("PhysicsMaxFrameTime") or maxFrameTime
        gravity = kernel.Config:Get("PhysicsGravity") or gravity
        rewindCaptureInterval = kernel.Config:Get("PhysicsRewindCaptureInterval") or rewindCaptureInterval
        constraintIterations = kernel.Config:Get("PhysicsConstraintIterations") or constraintIterations
        collisionIterations = kernel.Config:Get("PhysicsCollisionIterations") or collisionIterations
        maxSpeed = kernel.Config:Get("PhysicsMaxSpeed") or maxSpeed
        maxCollisionRecordsPerStep = kernel.Config:Get("PhysicsMaxCollisionRecordsPerStep") or maxCollisionRecordsPerStep
        if kernel.Config:Get("PhysicsCaptureStateDiff") == false then
            captureStateDiff = false
        end
        penetrationSlop = kernel.Config:Get("PhysicsPenetrationSlop") or penetrationSlop
        baumgarte = kernel.Config:Get("PhysicsBaumgarte") or baumgarte
        maxCorrection = kernel.Config:Get("PhysicsMaxCorrection") or maxCorrection
        sleepVelocity = kernel.Config:Get("PhysicsSleepVelocity") or sleepVelocity
        sleepFrames = kernel.Config:Get("PhysicsSleepFrames") or sleepFrames
    end

    local simulation = kernel and kernel.Simulation
    self.Pipeline = simulation and simulation.PhysicsPipeline or PhysicsPipeline.new({
        FixedStep = fixedStep,
        MaxSubsteps = maxSubsteps,
        MaxFrameTime = maxFrameTime,
        Gravity = gravity,
        RewindCaptureInterval = rewindCaptureInterval,
        ConstraintIterations = constraintIterations,
        CollisionIterations = collisionIterations,
        MaxCollisionRecordsPerStep = maxCollisionRecordsPerStep,
        CaptureStateDiff = captureStateDiff,
        MaxSpeed = maxSpeed,
        PenetrationSlop = penetrationSlop,
        Baumgarte = baumgarte,
        MaxCorrection = maxCorrection,
        SleepVelocity = sleepVelocity,
        SleepFrames = sleepFrames,
    })

    if simulation then
        simulation.PhysicsPipeline = self.Pipeline
    end
end

function PhysicsSubsystem:SetControlSource(source)
    self.ControlSource = normalizeSource(source)
end

function PhysicsSubsystem:GetControlSource()
    return self.ControlSource
end

function PhysicsSubsystem:Start()
end

function PhysicsSubsystem:Tick(dt)
    if self.Reader and self.Reader.Tick then
        self.Reader:Tick(dt)
    end

    if self.ControlSource == SOURCE_HELIX then
        local simulation = self.Kernel and self.Kernel.Simulation
        if simulation and not simulation.Pause and self.Pipeline then
            local result = self.Pipeline:Step(simulation, dt or 0, self.Kernel)
            if result then
                if self.Writer and self.Writer.Enqueue then
                    -- Host writes are deferred until simulation stepping is complete.
                    self.Writer:Enqueue("SetGravity", { Value = self.Pipeline.Config.Gravity })
                    self.Writer:Enqueue("SetFallenPartsDestroyHeight", { Value = -500 })
                end
            end
        end
    end

    if self.Writer and self.Writer.Tick then
        self.Writer:Tick(dt)
    end
end

function PhysicsSubsystem:Stop()
    if self.Reader and self.Reader.Shutdown then
        self.Reader:Shutdown()
    end

    if self.Writer and self.Writer.Shutdown then
        self.Writer:Shutdown()
    end
end

return PhysicsSubsystem
