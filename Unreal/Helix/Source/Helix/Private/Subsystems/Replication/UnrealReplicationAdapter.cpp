#include "Subsystems/Replication/UnrealReplicationAdapter.h"
#include "Engine/Engine.h"

void UnrealReplicationAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][Replication] Unreal adapter Initialize"));
}

void UnrealReplicationAdapter::Update(float FixedDeltaTime)
{
    // TODO: Bridge to Unreal replication systems
    (void)FixedDeltaTime;
}

void UnrealReplicationAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][Replication] Unreal adapter Shutdown"));
}
