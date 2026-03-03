#include "Subsystems/Input/UnrealInputAdapter.h"
#include "Engine/Engine.h"
#include "Engine/World.h"

void UnrealInputAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealInputAdapter] Initialized"));
}

void UnrealInputAdapter::Update(float FixedDeltaTime)
{
    UE_LOG(LogTemp, VeryVerbose, TEXT("[UnrealInputAdapter] Tick"));
}

void UnrealInputAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealInputAdapter] Shutdown"));
}
