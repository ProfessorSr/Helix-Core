#include "Subsystems/Audio/UnrealAudioAdapter.h"
#include "Engine/Engine.h"
#include "Engine/World.h"

void UnrealAudioAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealAudioAdapter] Initialized"));
}

void UnrealAudioAdapter::Update(float FixedDeltaTime)
{
    UE_LOG(LogTemp, VeryVerbose, TEXT("[UnrealAudioAdapter] Tick"));
}

void UnrealAudioAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealAudioAdapter] Shutdown"));
}
