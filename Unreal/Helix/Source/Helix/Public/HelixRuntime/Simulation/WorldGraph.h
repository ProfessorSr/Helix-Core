#pragma once

#include "CoreMinimal.h"

using FHelixEntityId = int64;

enum class EHelixColliderShape : uint8
{
    Sphere = 0,
    Box = 1,
    Capsule = 2,
    MeshBounds = 3
};

struct FBodyComponent
{
    FVector3d Position = FVector3d::ZeroVector;
    FVector3d Velocity = FVector3d::ZeroVector;
    double Mass = 1.0;
    bool bEnableGravity = true;
    double Radius = 50.0;
    FVector3d HalfExtents = FVector3d(50.0, 50.0, 50.0);
    double CapsuleHalfHeight = 50.0;
    EHelixColliderShape Shape = EHelixColliderShape::Sphere;
    bool bSleeping = false;
    int32 SleepFrames = 0;
};

struct FConstraintComponent
{
    FHelixEntityId A = 0;
    FHelixEntityId B = 0;
    double RestLength = 100.0;
    double Damping = 0.05;
};

struct FSimulationState
{
    int32 Tick = 0;
    FHelixEntityId NextEntityId = 1;
    TMap<FHelixEntityId, FBodyComponent> Bodies;
    TArray<FConstraintComponent> Constraints;
};

class FWorldGraph
{
public:
    static FHelixEntityId CreateEntity(FSimulationState& State);
    static uint64 HashDeterministicSnapshot(const FSimulationState& State);
    static uint64 HashPhysicsSignature(const FSimulationState& State);
};
