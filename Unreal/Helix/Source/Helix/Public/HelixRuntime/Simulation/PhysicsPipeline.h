#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Simulation/Broadphase.h"
#include "HelixRuntime/Simulation/CollisionPipeline.h"
#include "HelixRuntime/Simulation/ConstraintSolver.h"

struct FHelixConfig;

struct FPhysicsStepStats
{
    int32 Substeps = 0;
    int32 BroadphasePairs = 0;
    int32 Collisions = 0;
};

class FPhysicsPipeline
{
public:
    FPhysicsStepStats Tick(FSimulationState& State, const FHelixConfig& Config, double Dt) const;

private:
    FBroadphase Broadphase;
    FCollisionPipeline Collision;
    FConstraintSolver Constraints;
};
