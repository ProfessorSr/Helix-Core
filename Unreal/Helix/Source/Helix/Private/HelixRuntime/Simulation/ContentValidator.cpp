#include "HelixRuntime/Simulation/ContentValidator.h"
#include "HelixRuntime/Core/HelixLog.h"

bool FContentValidator::ValidateAndSanitizeBody(FBodyComponent& Body, FString& OutReason)
{
    OutReason.Reset();

    if (!IsFinite(Body.Position.X) || !IsFinite(Body.Position.Y) || !IsFinite(Body.Position.Z) ||
        !IsFinite(Body.Velocity.X) || !IsFinite(Body.Velocity.Y) || !IsFinite(Body.Velocity.Z))
    {
        OutReason = TEXT("nan_inf_vector");
        UE_LOG(LogHelixValidation, Warning, TEXT("[Schema] Invalid snapshot | Domain=Body | Reason=%s"), *OutReason);
        return false;
    }

    if (!IsFinite(Body.Mass) || Body.Mass <= 0.0)
    {
        Body.Mass = 1.0;
    }

    Body.Mass = FMath::Clamp(Body.Mass, 0.001, 10000.0);
    Body.Radius = FMath::Clamp(Body.Radius, 0.01, 100000.0);

    return true;
}

bool FContentValidator::ValidateAndSanitizeConstraint(FConstraintComponent& Constraint, const FSimulationState& State, FString& OutReason)
{
    OutReason.Reset();

    if (Constraint.A == Constraint.B || !State.Bodies.Contains(Constraint.A) || !State.Bodies.Contains(Constraint.B))
    {
        OutReason = TEXT("invalid_constraint_entity");
        UE_LOG(LogHelixValidation, Warning, TEXT("[Schema] Invalid snapshot | Domain=Constraint | Reason=%s"), *OutReason);
        return false;
    }

    if (!IsFinite(Constraint.RestLength))
    {
        OutReason = TEXT("nan_inf_rest_length");
        UE_LOG(LogHelixValidation, Warning, TEXT("[Schema] Invalid snapshot | Domain=Constraint | Reason=%s"), *OutReason);
        return false;
    }

    Constraint.RestLength = FMath::Clamp(Constraint.RestLength, 0.0, 100000.0);
    Constraint.Damping = FMath::Clamp(Constraint.Damping, 0.0, 1.0);

    return true;
}

bool FContentValidator::IsFinite(double Value)
{
    return FMath::IsFinite(Value);
}
