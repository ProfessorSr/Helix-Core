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
        Fold(static_cast<uint64>(Body.Shape));
        Fold(static_cast<uint64>(Body.bEnableGravity ? 1 : 0));
        Fold(static_cast<uint64>(Body.HalfExtents.X * 1000.0));
        Fold(static_cast<uint64>(Body.HalfExtents.Y * 1000.0));
        Fold(static_cast<uint64>(Body.HalfExtents.Z * 1000.0));
        Fold(static_cast<uint64>(Body.CapsuleHalfHeight * 1000.0));
    }

    return Hash;
}

uint64 FWorldGraph::HashPhysicsSignature(const FSimulationState& State)
{
    uint64 Hash = 1469598103934665603ull;

    auto Fold = [&Hash](uint64 Value)
    {
        Hash ^= Value;
        Hash *= 1099511628211ull;
    };

    TArray<FHelixEntityId> BodyKeys;
    State.Bodies.GetKeys(BodyKeys);
    BodyKeys.Sort();

    Fold(static_cast<uint64>(BodyKeys.Num()));
    for (FHelixEntityId Id : BodyKeys)
    {
        const FBodyComponent& Body = State.Bodies[Id];
        Fold(static_cast<uint64>(Id));
        Fold(static_cast<uint64>(Body.Position.X * 1000.0));
        Fold(static_cast<uint64>(Body.Position.Y * 1000.0));
        Fold(static_cast<uint64>(Body.Position.Z * 1000.0));
        Fold(static_cast<uint64>(Body.Velocity.X * 1000.0));
        Fold(static_cast<uint64>(Body.Velocity.Y * 1000.0));
        Fold(static_cast<uint64>(Body.Velocity.Z * 1000.0));
        Fold(static_cast<uint64>(Body.Mass * 1000.0));
        Fold(static_cast<uint64>(Body.Radius * 1000.0));
        Fold(static_cast<uint64>(Body.Shape));
        Fold(static_cast<uint64>(Body.bEnableGravity ? 1 : 0));
        Fold(static_cast<uint64>(Body.HalfExtents.X * 1000.0));
        Fold(static_cast<uint64>(Body.HalfExtents.Y * 1000.0));
        Fold(static_cast<uint64>(Body.HalfExtents.Z * 1000.0));
        Fold(static_cast<uint64>(Body.CapsuleHalfHeight * 1000.0));
        Fold(static_cast<uint64>(Body.bSleeping ? 1 : 0));
    }

    Fold(static_cast<uint64>(State.Constraints.Num()));
    for (const FConstraintComponent& Constraint : State.Constraints)
    {
        Fold(static_cast<uint64>(Constraint.A));
        Fold(static_cast<uint64>(Constraint.B));
        Fold(static_cast<uint64>(Constraint.RestLength * 1000.0));
        Fold(static_cast<uint64>(Constraint.Damping * 100000.0));
    }

    return Hash;
}
