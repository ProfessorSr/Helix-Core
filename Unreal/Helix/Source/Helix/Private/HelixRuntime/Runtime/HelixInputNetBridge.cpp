#include "HelixRuntime/Runtime/HelixInputNetBridge.h"

#include "Engine/GameInstance.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerState.h"
#include "HelixRuntime/Core/HelixLog.h"
#include "HelixRuntime/Runtime/HelixRuntimeSubsystem.h"

AHelixInputNetBridge::AHelixInputNetBridge()
{
    bReplicates = true;
    bAlwaysRelevant = true;
    bNetLoadOnClient = false;
    SetReplicateMovement(false);
    SetCanBeDamaged(false);

    PrimaryActorTick.bCanEverTick = false;
}

void AHelixInputNetBridge::ServerSubmitInput_Implementation(const FHelixNetInputPacket& Packet)
{
    UHelixRuntimeSubsystem* RuntimeSubsystem = ResolveRuntimeSubsystem();
    if (!RuntimeSubsystem)
    {
        return;
    }

    FString RejectReason;
    const bool bAccepted = RuntimeSubsystem->QueueClientInputFromNet(ResolvePlayerId(), Packet, RejectReason);
    if (!bAccepted)
    {
        ClientNotifyInputRejected(Packet.Tick, Packet.Sequence, RejectReason);
    }
}

void AHelixInputNetBridge::ClientNotifyInputRejected_Implementation(int32 Tick, int32 Sequence, const FString& Reason)
{
    UE_LOG(LogHelixNet, Warning, TEXT("[HelixNetBridge] Input rejected Tick=%d Seq=%d Reason=%s"), Tick, Sequence, *Reason);
}

UHelixRuntimeSubsystem* AHelixInputNetBridge::ResolveRuntimeSubsystem() const
{
    if (const UWorld* World = GetWorld())
    {
        if (UGameInstance* GameInstance = World->GetGameInstance())
        {
            return GameInstance->GetSubsystem<UHelixRuntimeSubsystem>();
        }
    }

    return nullptr;
}

FName AHelixInputNetBridge::ResolvePlayerId() const
{
    if (const APlayerController* PlayerController = Cast<APlayerController>(GetOwner()))
    {
        if (const APlayerState* PlayerState = PlayerController->GetPlayerState<APlayerState>())
        {
            return FName(*FString::FromInt(PlayerState->GetPlayerId()));
        }
    }

    return TEXT("Unknown");
}
