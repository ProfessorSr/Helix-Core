#include "HelixRuntime/Simulation/SpatialHierarchy.h"

TArray<FBroadphasePair> FSpatialHierarchy::BuildPairs(const TMap<FHelixEntityId, FBodyComponent>& Bodies)
{
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
        Proxies.Add({ Entry.Key, Body.Position.X - Body.Radius, Body.Position.X + Body.Radius });
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
