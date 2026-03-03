#include "HelixRuntime/Simulation/CollisionPipeline.h"

FCollisionStats FCollisionPipeline::Run(
    FSimulationState& State,
    const TArray<FBroadphasePair>& Pairs,
    int32 Iterations,
    double Baumgarte,
    double Slop,
    double MaxCorrection,
    double MaxSpeed) const
{
    FCollisionStats Stats;
    Stats.PairCount = Pairs.Num();

    for (int32 Iter = 0; Iter < Iterations; ++Iter)
    {
        for (const FBroadphasePair& Pair : Pairs)
        {
            FBodyComponent* A = State.Bodies.Find(Pair.A);
            FBodyComponent* B = State.Bodies.Find(Pair.B);
            if (!A || !B)
            {
                continue;
            }

            const FVector3d Delta = B->Position - A->Position;
            const double DistSq = Delta.SizeSquared();
            const double MinDist = A->Radius + B->Radius;
            if (DistSq <= KINDA_SMALL_NUMBER || DistSq >= MinDist * MinDist)
            {
                continue;
            }

            const double Dist = FMath::Sqrt(DistSq);
            const FVector3d Normal = Delta / Dist;
            const double Penetration = MinDist - Dist;
            const double Bias = FMath::Clamp((Penetration - Slop) * Baumgarte, 0.0, MaxCorrection);

            const double InvMassA = A->Mass > 0.0 ? (1.0 / A->Mass) : 0.0;
            const double InvMassB = B->Mass > 0.0 ? (1.0 / B->Mass) : 0.0;
            const double InvMassSum = InvMassA + InvMassB;
            if (InvMassSum <= KINDA_SMALL_NUMBER)
            {
                continue;
            }

            const FVector3d Correction = (Bias / InvMassSum) * Normal;
            A->Position -= Correction * InvMassA;
            B->Position += Correction * InvMassB;

            A->Velocity = A->Velocity.GetClampedToMaxSize(MaxSpeed);
            B->Velocity = B->Velocity.GetClampedToMaxSize(MaxSpeed);

            ++Stats.CollisionCount;
        }
    }

    return Stats;
}
