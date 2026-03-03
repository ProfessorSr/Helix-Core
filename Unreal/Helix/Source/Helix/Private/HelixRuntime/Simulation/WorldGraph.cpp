#include "HelixRuntime/Simulation/WorldGraph.h"

FHelixEntityId FWorldGraph::CreateEntity(FSimulationState& State)
{
    const FHelixEntityId NewId = State.NextEntityId++;
    State.Bodies.Add(NewId, FBodyComponent());
    return NewId;
}

uint64 FWorldGraph::HashDeterministicSnapshot(const FSimulationState& State)
{
    uint64 Hash = 1469598103934665603ull;

    TArray<FHelixEntityId> Keys;
    State.Bodies.GetKeys(Keys);
    Keys.Sort();

    auto Fold = [&Hash](uint64 Value)
    {
        Hash ^= Value;
        Hash *= 1099511628211ull;
    };

    Fold(static_cast<uint64>(State.Tick));
    Fold(static_cast<uint64>(Keys.Num()));

    for (FHelixEntityId Id : Keys)
    {
        const FBodyComponent& Body = State.Bodies[Id];
        Fold(static_cast<uint64>(Id));
        Fold(static_cast<uint64>(Body.Position.X * 1000.0));
        Fold(static_cast<uint64>(Body.Position.Y * 1000.0));
        Fold(static_cast<uint64>(Body.Position.Z * 1000.0));
        Fold(static_cast<uint64>(Body.Velocity.X * 1000.0));
        Fold(static_cast<uint64>(Body.Velocity.Y * 1000.0));
        Fold(static_cast<uint64>(Body.Velocity.Z * 1000.0));
    }

    return Hash;
}
