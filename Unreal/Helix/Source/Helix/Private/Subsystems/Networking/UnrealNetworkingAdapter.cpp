#include "Engine/Engine.h"
#include "Subsystems/Networking/UnrealNetworkingAdapter.h"

void UnrealNetworkingAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][Networking] Unreal adapter Initialize"));
}

void UnrealNetworkingAdapter::Update(float FixedDeltaTime)
{
    // TODO: Bridge to Unreal networking layer
    (void)FixedDeltaTime;
}

void UnrealNetworkingAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][Networking] Unreal adapter Shutdown"));
}
