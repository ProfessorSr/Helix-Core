#include "HelixRuntime/Simulation/ConstraintSolver.h"

void FConstraintSolver::Solve(FSimulationState& State, int32 Iterations) const
{
    for (int32 Iter = 0; Iter < Iterations; ++Iter)
    {
        for (const FConstraintComponent& Constraint : State.Constraints)
        {
            FBodyComponent* A = State.Bodies.Find(Constraint.A);
            FBodyComponent* B = State.Bodies.Find(Constraint.B);
            if (!A || !B)
            {
                continue;
            }

            const FVector3d Delta = B->Position - A->Position;
            const double Dist = Delta.Size();
            if (Dist <= KINDA_SMALL_NUMBER)
            {
                continue;
            }

            const FVector3d Normal = Delta / Dist;
            const double Error = Dist - Constraint.RestLength;
            const FVector3d Correction = (Error * 0.5) * Normal;

            A->Position += Correction;
            B->Position -= Correction;

            A->Velocity *= (1.0 - Constraint.Damping);
            B->Velocity *= (1.0 - Constraint.Damping);
        }
    }
}
