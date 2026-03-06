#include "HelixRuntime/Simulation/CollisionPipeline.h"

namespace
{
FVector3d ComputeHalfExtents(const FBodyComponent& Body)
{
    switch (Body.Shape)
    {
    case EHelixColliderShape::Sphere:
        return FVector3d(Body.Radius, Body.Radius, Body.Radius);
    case EHelixColliderShape::Capsule:
        return FVector3d(Body.Radius, Body.Radius, FMath::Max(Body.Radius, Body.CapsuleHalfHeight));
    case EHelixColliderShape::Box:
    case EHelixColliderShape::MeshBounds:
    default:
        return Body.HalfExtents;
    }
}

bool ResolveSphereSphere(
    const FBodyComponent& A,
    const FBodyComponent& B,
    FVector3d& OutNormal,
    double& OutPenetration)
{
    const FVector3d Delta = B.Position - A.Position;
    const double DistSq = Delta.SizeSquared();
    const double MinDist = A.Radius + B.Radius;
    if (DistSq <= KINDA_SMALL_NUMBER || DistSq >= MinDist * MinDist)
    {
        return false;
    }

    const double Dist = FMath::Sqrt(DistSq);
    OutNormal = Delta / Dist;
    OutPenetration = MinDist - Dist;
    return true;
}

bool ResolveAabbAabb(
    const FBodyComponent& A,
    const FBodyComponent& B,
    FVector3d& OutNormal,
    double& OutPenetration)
{
    const FVector3d ExtA = ComputeHalfExtents(A);
    const FVector3d ExtB = ComputeHalfExtents(B);
    const FVector3d Delta = B.Position - A.Position;

    const double OverlapX = (ExtA.X + ExtB.X) - FMath::Abs(Delta.X);
    const double OverlapY = (ExtA.Y + ExtB.Y) - FMath::Abs(Delta.Y);
    const double OverlapZ = (ExtA.Z + ExtB.Z) - FMath::Abs(Delta.Z);
    if (OverlapX <= 0.0 || OverlapY <= 0.0 || OverlapZ <= 0.0)
    {
        return false;
    }

    // For stacked/resting contacts, prefer vertical separation to avoid lateral creep.
    if (FMath::Abs(Delta.Z) >= FMath::Abs(Delta.X) && FMath::Abs(Delta.Z) >= FMath::Abs(Delta.Y))
    {
        OutPenetration = OverlapZ;
        OutNormal = FVector3d(0.0, 0.0, (Delta.Z >= 0.0) ? 1.0 : -1.0);
        return true;
    }

    // Prefer vertical separation when overlaps are near-tied to reduce startup side drift in stacked bodies.
    static constexpr double AxisTieEpsilon = 0.5; // centimeters
    const double MinOverlap = FMath::Min3(OverlapX, OverlapY, OverlapZ);
    if (OverlapZ <= MinOverlap + AxisTieEpsilon)
    {
        OutPenetration = OverlapZ;
        OutNormal = FVector3d(0.0, 0.0, (Delta.Z >= 0.0) ? 1.0 : -1.0);
        return true;
    }

    if (OverlapX <= OverlapY)
    {
        OutPenetration = OverlapX;
        OutNormal = FVector3d((Delta.X >= 0.0) ? 1.0 : -1.0, 0.0, 0.0);
    }
    else
    {
        OutPenetration = OverlapY;
        OutNormal = FVector3d(0.0, (Delta.Y >= 0.0) ? 1.0 : -1.0, 0.0);
    }

    return true;
}

bool ResolveSphereAabb(
    const FBodyComponent& SphereBody,
    const FBodyComponent& BoxBody,
    FVector3d& OutNormalSphereToBox,
    double& OutPenetration)
{
    const FVector3d Ext = ComputeHalfExtents(BoxBody);
    const FVector3d Min = BoxBody.Position - Ext;
    const FVector3d Max = BoxBody.Position + Ext;

    const FVector3d Closest(
        FMath::Clamp(SphereBody.Position.X, Min.X, Max.X),
        FMath::Clamp(SphereBody.Position.Y, Min.Y, Max.Y),
        FMath::Clamp(SphereBody.Position.Z, Min.Z, Max.Z));

    const FVector3d Delta = Closest - SphereBody.Position;
    const double DistSq = Delta.SizeSquared();
    const double RadiusSq = SphereBody.Radius * SphereBody.Radius;
    if (DistSq > RadiusSq)
    {
        return false;
    }

    if (DistSq > KINDA_SMALL_NUMBER)
    {
        const double Dist = FMath::Sqrt(DistSq);
        OutNormalSphereToBox = Delta / Dist;
        OutPenetration = SphereBody.Radius - Dist;
        return OutPenetration > 0.0;
    }

    const FVector3d Local = SphereBody.Position - BoxBody.Position;
    const double ToMinX = Local.X + Ext.X;
    const double ToMaxX = Ext.X - Local.X;
    const double ToMinY = Local.Y + Ext.Y;
    const double ToMaxY = Ext.Y - Local.Y;
    const double ToMinZ = Local.Z + Ext.Z;
    const double ToMaxZ = Ext.Z - Local.Z;

    OutNormalSphereToBox = FVector3d(1.0, 0.0, 0.0);
    double MinToFace = ToMaxX;

    if (ToMinX < MinToFace)
    {
        MinToFace = ToMinX;
        OutNormalSphereToBox = FVector3d(-1.0, 0.0, 0.0);
    }
    if (ToMinY < MinToFace)
    {
        MinToFace = ToMinY;
        OutNormalSphereToBox = FVector3d(0.0, -1.0, 0.0);
    }
    if (ToMaxY < MinToFace)
    {
        MinToFace = ToMaxY;
        OutNormalSphereToBox = FVector3d(0.0, 1.0, 0.0);
    }
    if (ToMinZ < MinToFace)
    {
        MinToFace = ToMinZ;
        OutNormalSphereToBox = FVector3d(0.0, 0.0, -1.0);
    }
    if (ToMaxZ < MinToFace)
    {
        MinToFace = ToMaxZ;
        OutNormalSphereToBox = FVector3d(0.0, 0.0, 1.0);
    }

    OutPenetration = SphereBody.Radius + FMath::Max(0.0, MinToFace);
    return OutPenetration > 0.0;
}
}

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

            FVector3d Normal = FVector3d::ZeroVector;
            double Penetration = 0.0;
            bool bHasCollision = false;

            const bool bSphereA = (A->Shape == EHelixColliderShape::Sphere);
            const bool bSphereB = (B->Shape == EHelixColliderShape::Sphere);
            if (bSphereA && bSphereB)
            {
                bHasCollision = ResolveSphereSphere(*A, *B, Normal, Penetration);
            }
            else if (bSphereA && !bSphereB)
            {
                bHasCollision = ResolveSphereAabb(*A, *B, Normal, Penetration);
            }
            else if (!bSphereA && bSphereB)
            {
                bHasCollision = ResolveSphereAabb(*B, *A, Normal, Penetration);
                Normal = -Normal;
            }
            else
            {
                bHasCollision = ResolveAabbAabb(*A, *B, Normal, Penetration);
            }

            if (!bHasCollision)
            {
                continue;
            }
            const double InvMassA = A->Mass > 0.0 ? (1.0 / A->Mass) : 0.0;
            const double InvMassB = B->Mass > 0.0 ? (1.0 / B->Mass) : 0.0;
            const double InvMassSum = InvMassA + InvMassB;
            if (InvMassSum <= KINDA_SMALL_NUMBER)
            {
                continue;
            }

            const bool bHasStaticBody = (InvMassA <= KINDA_SMALL_NUMBER || InvMassB <= KINDA_SMALL_NUMBER);
            double Bias = 0.0;
            if (bHasStaticBody)
            {
                // Static contacts should be stronger than Baumgarte, but still bounded to prevent launch artifacts.
                Bias = FMath::Clamp(Penetration - Slop, 0.0, MaxCorrection);
            }
            else
            {
                Bias = FMath::Clamp((Penetration - Slop) * Baumgarte, 0.0, MaxCorrection);
            }
            if (Bias <= KINDA_SMALL_NUMBER)
            {
                continue;
            }
            const FVector3d Correction = (Bias / InvMassSum) * Normal;
            A->Position -= Correction * InvMassA;
            B->Position += Correction * InvMassB;

            // Kill inward relative normal velocity so corrected contacts remain stable.
            const double RelativeNormalVelocity = FVector3d::DotProduct(B->Velocity - A->Velocity, Normal);
            if (RelativeNormalVelocity < 0.0)
            {
                const double Impulse = -RelativeNormalVelocity / InvMassSum;
                A->Velocity -= (Impulse * InvMassA) * Normal;
                B->Velocity += (Impulse * InvMassB) * Normal;
            }

            A->Velocity = A->Velocity.GetClampedToMaxSize(MaxSpeed);
            B->Velocity = B->Velocity.GetClampedToMaxSize(MaxSpeed);

            if (bHasStaticBody && FMath::Abs(Normal.Z) >= 0.75)
            {
                auto StabilizeTangential = [](FBodyComponent& Body)
                {
                    if (Body.Mass <= 0.0)
                    {
                        return;
                    }

                    static constexpr double RestingTangentialSpeed = 3.0; // cm/s
                    const double TangentialSpeedSq = Body.Velocity.X * Body.Velocity.X + Body.Velocity.Y * Body.Velocity.Y;
                    if (TangentialSpeedSq <= RestingTangentialSpeed * RestingTangentialSpeed)
                    {
                        Body.Velocity.X = 0.0;
                        Body.Velocity.Y = 0.0;
                    }
                };

                StabilizeTangential(*A);
                StabilizeTangential(*B);
            }

            ++Stats.CollisionCount;
        }
    }

    return Stats;
}
