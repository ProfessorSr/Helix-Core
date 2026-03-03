#include "Subsystems/Camera/UnrealCameraAdapter.h"
#include "Engine/Engine.h"
#include "Engine/World.h"

void UnrealCameraAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealCameraAdapter] Initialized"));
}

void UnrealCameraAdapter::Update(float FixedDeltaTime)
{
    UE_LOG(LogTemp, VeryVerbose, TEXT("[UnrealCameraAdapter] Tick"));
}

void UnrealCameraAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealCameraAdapter] Shutdown"));
}
