#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Containers/Ticker.h"
#include "HelixRuntime/Runtime/RuntimeEntrypoint.h"
#include "HelixRuntimeSubsystem.generated.h"

class APlayerController;
class AHelixInputNetBridge;
struct FHelixNetInputPacket;

UCLASS()
class HELIX_API UHelixRuntimeSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    virtual void Deinitialize() override;

    bool StartRuntime();

    void StopRuntime();

    bool SetSubsystemControlSource(FName SubsystemName, FName Source);

    FDebugInspectorData GetInspectorData() const;

    FStressTestResult RunSimulationStressTest(int32 EntityCount, int32 Steps, double Radius, double Amplitude);

    void BeginReplayCertification(const FString& ScenarioId);

    FReplayCertificate EndReplayCertification();
    bool QueueClientInputFromNet(FName PlayerId, const FHelixNetInputPacket& Packet, FString& OutRejectReason);
    AHelixInputNetBridge* SpawnInputBridgeForPlayer(APlayerController* PlayerController);

private:
    bool TickRuntime(float DeltaSeconds);
    void LogStartupCapabilities() const;
    void EnsureDebugPanel();
    void TeardownDebugPanel();
    void RefreshDebugPanel();
    int32 DestroyPhysicsTestRigs();

    FRuntimeEntrypoint Runtime;
    FTSTicker::FDelegateHandle TickHandle;
    bool bRuntimeStarted = false;
    bool bPendingRigCleanup = false;
    double RuntimeLogAccumulator = 0.0;
    uint64 LastLoggedTick = 0;
    TSharedPtr<class SWidget> DebugPanelRoot;
    TSharedPtr<class STextBlock> DebugPanelText;
};
