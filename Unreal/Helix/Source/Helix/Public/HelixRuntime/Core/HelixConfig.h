#pragma once

#include "CoreMinimal.h"

struct FHelixConfig
{
    double TickRate = 60.0;
    int32 MaxStepsPerFrame = 8;
    bool bProfileEnabled = true;
    bool bDebugPanelEnabled = true;
    bool bAuthoritativeNetEnabled = true;
    bool bUseHelixPhysics = true;

    double PhysicsFixedStep = 1.0 / 60.0;
    int32 PhysicsMaxSubsteps = 4;
    int32 PhysicsCollisionIterations = 4;
    int32 PhysicsConstraintIterations = 4;
    double PhysicsMaxSpeed = 6000.0;
    double PhysicsPenetrationSlop = 0.01;
    double PhysicsBaumgarte = 0.2;
    double PhysicsMaxCorrection = 2.0;
    double PhysicsSleepVelocity = 1.0;
    int32 PhysicsSleepFrames = 8;
    double PhysicsGravityZ = -980.0;
    int32 PhysicsMaxCollisionRecordsPerStep = 2048;
    bool bPhysicsCaptureStateDiff = true;

    int32 NetworkingMaxFutureTicks = 4;
    int32 NetworkingMaxPastTicks = 12;
    int32 NetworkingMaxInputsPerPlayerPerTick = 8;
    int32 NetworkingMaxInputsPerTick = 2048;
    int32 NetworkingRejectBufferSize = 512;

    bool bLocked = false;

    void Lock() { bLocked = true; }

    template <typename T>
    void Set(T& Field, const T& Value)
    {
        if (!bLocked)
        {
            Field = Value;
        }
    }

    double FixedStep() const
    {
        return TickRate > 0.0 ? (1.0 / TickRate) : (1.0 / 60.0);
    }
};
