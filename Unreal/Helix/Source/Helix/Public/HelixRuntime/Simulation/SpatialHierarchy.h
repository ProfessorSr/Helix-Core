#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Simulation/WorldGraph.h"

struct FBroadphasePair
{
    FHelixEntityId A = 0;
    FHelixEntityId B = 0;

    bool operator<(const FBroadphasePair& Other) const
    {
        return A == Other.A ? B < Other.B : A < Other.A;
    }
};

class FSpatialHierarchy
{
public:
    static TArray<FBroadphasePair> BuildPairs(const TMap<FHelixEntityId, FBodyComponent>& Bodies);
};
