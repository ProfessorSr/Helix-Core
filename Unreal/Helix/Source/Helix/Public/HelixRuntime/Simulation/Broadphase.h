#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Simulation/SpatialHierarchy.h"

class FBroadphase
{
public:
    TArray<FBroadphasePair> Run(const TMap<FHelixEntityId, FBodyComponent>& Bodies) const;
};
