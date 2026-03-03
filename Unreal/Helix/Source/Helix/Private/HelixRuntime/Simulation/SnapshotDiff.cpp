#include "HelixRuntime/Simulation/SnapshotDiff.h"

FSnapshotDiffResult FSnapshotDiff::Diff(const FSimulationState& Before, const FSimulationState& After)
{
    FSnapshotDiffResult Result;

    for (const TPair<FHelixEntityId, FBodyComponent>& Entry : After.Bodies)
    {
        const FBodyComponent* Previous = Before.Bodies.Find(Entry.Key);
        if (!Previous)
        {
            ++Result.AddedBodies;
            continue;
        }

        if (!Previous->Position.Equals(Entry.Value.Position) || !Previous->Velocity.Equals(Entry.Value.Velocity))
        {
            ++Result.ChangedBodies;
        }
    }

    for (const TPair<FHelixEntityId, FBodyComponent>& Entry : Before.Bodies)
    {
        if (!After.Bodies.Contains(Entry.Key))
        {
            ++Result.RemovedBodies;
        }
    }

    return Result;
}
