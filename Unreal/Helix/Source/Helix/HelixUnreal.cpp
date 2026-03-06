#include "HelixUnreal.h"
#include "Engine/Engine.h"

AHelixUnreal::AHelixUnreal()
{
    PrimaryActorTick.bCanEverTick = true;
}

void AHelixUnreal::BeginPlay()
{
    Super::BeginPlay();

    UE_LOG(LogTemp, Log, TEXT("[HelixUnreal] Legacy Unreal actor started."));
    Core.Boot();
}

void AHelixUnreal::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);
    Core.Update(DeltaTime);
}

void AHelixUnreal::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    Core.Shutdown();
    Super::EndPlay(EndPlayReason);
}
