#pragma once

#include "CoreMinimal.h"

using FHelixEntityId = int64;

struct FBodyComponent
{
    FVector3d Position = FVector3d::ZeroVector;
    FVector3d Velocity = FVector3d::ZeroVector;
    double Mass = 1.0;
    double Radius = 50.0;
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
};
