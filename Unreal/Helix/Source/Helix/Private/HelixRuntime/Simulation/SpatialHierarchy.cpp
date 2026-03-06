#include "HelixRuntime/Simulation/SpatialHierarchy.h"

TArray<FBroadphasePair> FSpatialHierarchy::BuildPairs(const TMap<FHelixEntityId, FBodyComponent>& Bodies)
{
    auto ComputeHalfExtents = [](const FBodyComponent& Body) -> FVector3d
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
    };

    struct FProxy
    {
        FHelixEntityId Id;
        double MinX;
        double MaxX;
    };

    TArray<FProxy> Proxies;
    Proxies.Reserve(Bodies.Num());

    for (const TPair<FHelixEntityId, FBodyComponent>& Entry : Bodies)
    {
        const FBodyComponent& Body = Entry.Value;
        const FVector3d HalfExtents = ComputeHalfExtents(Body);
        Proxies.Add({ Entry.Key, Body.Position.X - HalfExtents.X, Body.Position.X + HalfExtents.X });
    }

    Proxies.Sort([](const FProxy& A, const FProxy& B)
    {
        return A.MinX == B.MinX ? A.Id < B.Id : A.MinX < B.MinX;
    });

    TArray<FBroadphasePair> Pairs;
    for (int32 I = 0; I < Proxies.Num(); ++I)
    {
        for (int32 J = I + 1; J < Proxies.Num(); ++J)
        {
            if (Proxies[J].MinX > Proxies[I].MaxX)
            {
                break;
            }

            const FHelixEntityId A = FMath::Min(Proxies[I].Id, Proxies[J].Id);
            const FHelixEntityId B = FMath::Max(Proxies[I].Id, Proxies[J].Id);
            Pairs.Add({ A, B });
        }
    }

    Pairs.Sort();
    return Pairs;
}
