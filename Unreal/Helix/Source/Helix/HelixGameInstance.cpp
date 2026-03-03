#include "HelixGameInstance.h"
#include "HelixRuntime/Core/HelixLog.h"
#include "HelixRuntime/Runtime/HelixRuntimeSubsystem.h"
#include "Engine/Engine.h"

void UHelixGameInstance::Init()
{
    Super::Init();

    UHelixRuntimeSubsystem* RuntimeSubsystem = GetSubsystem<UHelixRuntimeSubsystem>();
    if (!RuntimeSubsystem)
    {
        UE_LOG(LogHelixRuntime, Error, TEXT("[HelixRuntime] GameInstance could not resolve UHelixRuntimeSubsystem."));
        return;
    }

    const bool bStarted = RuntimeSubsystem->StartRuntime();
    UE_LOG(LogHelixRuntime, Log, TEXT("[HelixRuntime] Auto-boot StartRuntime=%s"), bStarted ? TEXT("true") : TEXT("false"));
}

void UHelixGameInstance::Shutdown()
{
    Super::Shutdown();
}
