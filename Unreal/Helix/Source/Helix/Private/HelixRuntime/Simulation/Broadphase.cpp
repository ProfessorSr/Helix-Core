#include "HelixRuntime/Simulation/Broadphase.h"

TArray<FBroadphasePair> FBroadphase::Run(const TMap<FHelixEntityId, FBodyComponent>& Bodies) const
{
    return FSpatialHierarchy::BuildPairs(Bodies);
}
