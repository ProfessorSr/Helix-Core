#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Simulation/WorldGraph.h"
#include "HelixRuntime/Simulation/SpatialHierarchy.h"

struct FCollisionStats
{
    int32 PairCount = 0;
    int32 CollisionCount = 0;
};

class FCollisionPipeline
{
public:
    FCollisionStats Run(
        FSimulationState& State,
        const TArray<FBroadphasePair>& Pairs,
        int32 Iterations,
        double Baumgarte,
        double Slop,
        double MaxCorrection,
        double MaxSpeed) const;
};
