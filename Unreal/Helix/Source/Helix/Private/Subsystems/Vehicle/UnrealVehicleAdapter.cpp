#include "Subsystems/Vehicle/UnrealVehicleAdapter.h"
#include "Engine/Engine.h"

void UnrealVehicleAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][Vehicle] Unreal adapter Initialize"));
}

void UnrealVehicleAdapter::Update(float FixedDeltaTime)
{
    // TODO: Bridge to Unreal vehicle systems
    (void)FixedDeltaTime;
}

void UnrealVehicleAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[Helix][Vehicle] Unreal adapter Shutdown"));
}
