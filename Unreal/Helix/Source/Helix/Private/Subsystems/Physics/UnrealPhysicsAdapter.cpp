#include "Subsystems/Physics/UnrealPhysicsAdapter.h"
#include "Engine/Engine.h"
#include "Engine/World.h"

void UnrealPhysicsAdapter::Initialize()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealPhysicsAdapter] Initialized"));
}

void UnrealPhysicsAdapter::Update(float FixedDeltaTime)
{
    UE_LOG(LogTemp, VeryVerbose, TEXT("[UnrealPhysicsAdapter] Tick"));
}

void UnrealPhysicsAdapter::Shutdown()
{
    UE_LOG(LogTemp, Warning, TEXT("[UnrealPhysicsAdapter] Shutdown"));
}
