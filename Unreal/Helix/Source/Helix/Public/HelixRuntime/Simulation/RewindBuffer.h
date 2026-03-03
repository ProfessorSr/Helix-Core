#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Simulation/WorldGraph.h"

class FRewindBuffer
{
public:
    explicit FRewindBuffer(int32 InCapacity = 256) : Capacity(InCapacity) {}

    void Push(const FSimulationState& State);
    bool GetByTick(int32 Tick, FSimulationState& OutState) const;

private:
    int32 Capacity = 256;
    TArray<FSimulationState> States;
};
