#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Simulation/WorldGraph.h"

struct FSnapshotDiffResult
{
    int32 ChangedBodies = 0;
    int32 AddedBodies = 0;
    int32 RemovedBodies = 0;
};

class FSnapshotDiff
{
public:
    static FSnapshotDiffResult Diff(const FSimulationState& Before, const FSimulationState& After);
};
