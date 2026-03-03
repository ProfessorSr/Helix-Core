#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "HelixInputNetBridge.generated.h"

class UHelixRuntimeSubsystem;

USTRUCT(BlueprintType)
struct FHelixNetInputPacket
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Helix")
    int32 Tick = 0;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Helix")
    int32 Sequence = 0;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Helix")
    FName Command;
};

UCLASS()
class HELIX_API AHelixInputNetBridge : public AActor
{
    GENERATED_BODY()

public:
    AHelixInputNetBridge();

    UFUNCTION(Server, Reliable)
    void ServerSubmitInput(const FHelixNetInputPacket& Packet);

    UFUNCTION(Client, Unreliable)
    void ClientNotifyInputRejected(int32 Tick, int32 Sequence, const FString& Reason);

private:
    UHelixRuntimeSubsystem* ResolveRuntimeSubsystem() const;
    FName ResolvePlayerId() const;
};
