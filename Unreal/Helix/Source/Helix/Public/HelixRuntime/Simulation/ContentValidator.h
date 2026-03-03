#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Simulation/WorldGraph.h"

class FContentValidator
{
public:
    static bool ValidateAndSanitizeBody(FBodyComponent& Body, FString& OutReason);
    static bool ValidateAndSanitizeConstraint(FConstraintComponent& Constraint, const FSimulationState& State, FString& OutReason);

private:
    static bool IsFinite(double Value);
};
