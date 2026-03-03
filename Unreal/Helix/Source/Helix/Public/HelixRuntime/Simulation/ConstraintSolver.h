#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Simulation/WorldGraph.h"

class FConstraintSolver
{
public:
    void Solve(FSimulationState& State, int32 Iterations) const;
};
