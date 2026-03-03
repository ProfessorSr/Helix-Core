#include "Subsystems/Save/UnrealSaveLoadAdapter.h"
#include "Engine/Engine.h"

void UnrealSaveLoadAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][SaveLoad] Unreal adapter Initialize"));
}

void UnrealSaveLoadAdapter::Update(float FixedDeltaTime)
{
    // TODO: Bridge to Unreal save/load systems
    (void)FixedDeltaTime;
}

void UnrealSaveLoadAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][SaveLoad] Unreal adapter Shutdown"));
}
