#include "HelixGameInstance.h"
#include "HelixHost.h"
#include "Engine/World.h"

void UHelixGameInstance::Init()
{
    Super::Init();

    if (UWorld* World = GetWorld())
    {
        World->SpawnActor<AHelixHost>();
    }
}

void UHelixGameInstance::Shutdown()
{
    Super::Shutdown();
}
