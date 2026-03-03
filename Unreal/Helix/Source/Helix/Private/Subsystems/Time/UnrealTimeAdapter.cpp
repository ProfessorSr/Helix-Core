#include "Subsystems/Time/UnrealTimeAdapter.h"
#include "Engine/Engine.h"
#include "Engine/World.h"

void UnrealTimeAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealTimeAdapter] Initialized"));
}

void UnrealTimeAdapter::Update(float FixedDeltaTime)
{
    UE_LOG(LogTemp, VeryVerbose, TEXT("[UnrealTimeAdapter] Tick"));
}

void UnrealTimeAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealTimeAdapter] Shutdown"));
}
