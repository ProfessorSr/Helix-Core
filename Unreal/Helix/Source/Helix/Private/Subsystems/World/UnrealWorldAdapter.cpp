#include "Subsystems/World/UnrealWorldAdapter.h"
#include "Engine/Engine.h"

void UnrealWorldAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][World] Unreal adapter Initialize"));
}

void UnrealWorldAdapter::Update(float FixedDeltaTime)
{
    // TODO: Bridge to Unreal world systems
    (void)FixedDeltaTime;
}

void UnrealWorldAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][World] Unreal adapter Shutdown"));
}
