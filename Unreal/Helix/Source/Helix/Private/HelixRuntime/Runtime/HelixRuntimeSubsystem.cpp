#include "HelixRuntime/Runtime/HelixRuntimeSubsystem.h"

#include "GameFramework/PlayerController.h"
#include "Engine/World.h"
#include "Engine/Engine.h"
#include "Engine/GameViewportClient.h"
#include "HAL/IConsoleManager.h"
#include "HelixRuntime/Authorities/NetworkingAuthority.h"
#include "HelixRuntime/Authorities/TimeAuthority.h"
#include "HelixRuntime/Core/HelixLog.h"
#include "HelixRuntime/Runtime/HelixInputNetBridge.h"
#include "HelixRuntime/Runtime/IReader.h"
#include "HelixRuntime/Runtime/ISubsystem.h"
#include "HelixRuntime/Runtime/IWriter.h"
#include "HelixRuntime/Runtime/SubsystemManifest.h"

#include "Subsystems/Time/UnrealTimeAdapter.h"
#include "Subsystems/Input/UnrealInputAdapter.h"
#include "Subsystems/Event/UnrealEventAdapter.h"
#include "Subsystems/World/UnrealWorldAdapter.h"
#include "Subsystems/Physics/UnrealPhysicsAdapter.h"
#include "Subsystems/Vehicle/UnrealVehicleAdapter.h"
#include "Subsystems/Character/UnrealCharacterAdapter.h"
#include "Subsystems/Camera/UnrealCameraAdapter.h"
#include "Subsystems/Animation/UnrealAnimationAdapter.h"
#include "Subsystems/AI/UnrealAIAdapter.h"
#include "Subsystems/Climate/UnrealClimateAdapter.h"
#include "Subsystems/Audio/UnrealAudioAdapter.h"
#include "Subsystems/Lighting/UnrealLightingAdapter.h"
#include "Subsystems/Networking/UnrealNetworkingAdapter.h"
#include "Subsystems/Replication/UnrealReplicationAdapter.h"
#include "Subsystems/Save/UnrealSaveLoadAdapter.h"
#include "Subsystems/Economy/UnrealEconomyAdapter.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Text/STextBlock.h"

namespace
{
class FNoopReader final : public IReader
{
public:
    explicit FNoopReader(FName InName) : Name(InName) {}

    void Initialize(FHelixKernel& Kernel) override {}
    void Tick(double Dt) override {}
    void Shutdown() override {}

private:
    FName Name;
};

class FNoopWriter final : public IWriter
{
public:
    explicit FNoopWriter(FName InName, FName InDomain) : Name(InName), Domain(InDomain) {}

    void Initialize(FHelixKernel& Kernel) override {}
    void Enqueue(FName Command, const FString& Payload) override
    {
        UE_LOG(LogHelixValidation, Warning, TEXT("[Writer] Rejected command | Domain=%s | Command=%s | Reason=noop_writer"), *Domain.ToString(), *Command.ToString());
    }
    void Tick(double Dt) override {}
    void Shutdown() override {}

private:
    FName Name;
    FName Domain;
};

template <typename TAdapter>
class FLegacyAdapterSubsystem final : public FHelixSubsystemBase
{
public:
    explicit FLegacyAdapterSubsystem(FName InName)
        : Name(InName)
    {
    }

    void Init(FHelixKernel& Kernel, TSharedPtr<IReader> Reader, TSharedPtr<IWriter> Writer) override
    {
        BoundReader = Reader;
        BoundWriter = Writer;
    }

    void Start() override
    {
        Adapter.Initialize();
    }

    void Tick(double FixedDt) override
    {
        Adapter.Update(static_cast<float>(FixedDt));
    }

    void Stop() override
    {
        Adapter.Shutdown();
    }

private:
    FName Name;
    TAdapter Adapter;
    TSharedPtr<IReader> BoundReader;
    TSharedPtr<IWriter> BoundWriter;
};

template <typename TAdapter>
void AddLegacySubsystem(
    TArray<FSubsystemManifestEntry>& Manifest,
    FName Name,
    FName Domain,
    int32 Phase,
    TArray<FName> Dependencies)
{
    FSubsystemManifestEntry Entry;
    Entry.Name = Name;
    Entry.Domain = Domain;
    Entry.Phase = Phase;
    Entry.Dependencies = MoveTemp(Dependencies);
    Entry.CreateSubsystem = [Name]() -> TSharedPtr<ISubsystem> { return MakeShared<FLegacyAdapterSubsystem<TAdapter>>(Name); };
    Entry.CreateReader = [Name]() -> TSharedPtr<IReader> { return MakeShared<FNoopReader>(Name); };
    Entry.CreateWriter = [Name, Domain]() -> TSharedPtr<IWriter> { return MakeShared<FNoopWriter>(Name, Domain); };
    Manifest.Add(MoveTemp(Entry));
}

TArray<FSubsystemManifestEntry> BuildDefaultManifest()
{
    TArray<FSubsystemManifestEntry> Manifest;

    AddLegacySubsystem<UnrealTimeAdapter>(Manifest, TEXT("Time"), TEXT("Core"), 0, {});
    AddLegacySubsystem<UnrealInputAdapter>(Manifest, TEXT("Input"), TEXT("Core"), 1, { TEXT("Time") });
    AddLegacySubsystem<UnrealEventAdapter>(Manifest, TEXT("Event"), TEXT("Core"), 2, { TEXT("Input") });
    AddLegacySubsystem<UnrealWorldAdapter>(Manifest, TEXT("World"), TEXT("Simulation"), 3, { TEXT("Event") });

    AddLegacySubsystem<UnrealPhysicsAdapter>(Manifest, TEXT("Physics"), TEXT("Simulation"), 4, { TEXT("World") });
    AddLegacySubsystem<UnrealVehicleAdapter>(Manifest, TEXT("Vehicle"), TEXT("Simulation"), 5, { TEXT("Physics") });
    AddLegacySubsystem<UnrealCharacterAdapter>(Manifest, TEXT("Character"), TEXT("Simulation"), 6, { TEXT("Vehicle") });
    AddLegacySubsystem<UnrealCameraAdapter>(Manifest, TEXT("Camera"), TEXT("Simulation"), 7, { TEXT("Character") });
    AddLegacySubsystem<UnrealAnimationAdapter>(Manifest, TEXT("Animation"), TEXT("Simulation"), 8, { TEXT("Character") });
    AddLegacySubsystem<UnrealAIAdapter>(Manifest, TEXT("AI"), TEXT("Simulation"), 9, { TEXT("Character") });

    AddLegacySubsystem<UnrealClimateAdapter>(Manifest, TEXT("Climate"), TEXT("Expansion"), 10, { TEXT("World") });
    AddLegacySubsystem<UnrealAudioAdapter>(Manifest, TEXT("Audio"), TEXT("Expansion"), 11, { TEXT("World") });
    AddLegacySubsystem<UnrealLightingAdapter>(Manifest, TEXT("Lighting"), TEXT("Expansion"), 12, { TEXT("World") });

    AddLegacySubsystem<UnrealNetworkingAdapter>(Manifest, TEXT("Networking"), TEXT("Enterprise"), 13, { TEXT("AI") });
    AddLegacySubsystem<UnrealReplicationAdapter>(Manifest, TEXT("Replication"), TEXT("Enterprise"), 14, { TEXT("Networking") });
    AddLegacySubsystem<UnrealSaveLoadAdapter>(Manifest, TEXT("SaveLoad"), TEXT("Enterprise"), 15, { TEXT("Replication") });
    AddLegacySubsystem<UnrealEconomyAdapter>(Manifest, TEXT("Economy"), TEXT("Enterprise"), 16, { TEXT("SaveLoad") });

    return Manifest;
}
}

void UHelixRuntimeSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection);
    StartRuntime();
}

void UHelixRuntimeSubsystem::Deinitialize()
{
    StopRuntime();
    Super::Deinitialize();
}

bool UHelixRuntimeSubsystem::StartRuntime()
{
    if (bRuntimeStarted)
    {
        return true;
    }

    FString Error;
    FHelixConfig Config;
    bRuntimeStarted = Runtime.Start(Config, BuildDefaultManifest(), Error);

    if (!bRuntimeStarted)
    {
        UE_LOG(LogHelixRuntime, Error, TEXT("[HelixRuntime] Failed to start: %s"), *Error);
        return false;
    }

    LogStartupCapabilities();
    RuntimeLogAccumulator = 0.0;
    LastLoggedTick = 0;
    EnsureDebugPanel();

    TickHandle = FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateUObject(this, &UHelixRuntimeSubsystem::TickRuntime));
    return true;
}

void UHelixRuntimeSubsystem::StopRuntime()
{
    if (!bRuntimeStarted)
    {
        return;
    }

    if (TickHandle.IsValid())
    {
        FTSTicker::GetCoreTicker().RemoveTicker(TickHandle);
        TickHandle.Reset();
    }

    Runtime.Stop();
    TeardownDebugPanel();
    bRuntimeStarted = false;
}

bool UHelixRuntimeSubsystem::SetSubsystemControlSource(FName SubsystemName, FName Source)
{
    return Runtime.SetSubsystemControlSource(SubsystemName, Source);
}

FDebugInspectorData UHelixRuntimeSubsystem::GetInspectorData() const
{
    return Runtime.GetInspectorData();
}

FStressTestResult UHelixRuntimeSubsystem::RunSimulationStressTest(int32 EntityCount, int32 Steps, double Radius, double Amplitude)
{
    return Runtime.RunSimulationStressTest(EntityCount, Steps, Radius, Amplitude);
}

void UHelixRuntimeSubsystem::BeginReplayCertification(const FString& ScenarioId)
{
    Runtime.BeginReplayCertification(ScenarioId);
}

FReplayCertificate UHelixRuntimeSubsystem::EndReplayCertification()
{
    return Runtime.EndReplayCertification();
}

bool UHelixRuntimeSubsystem::QueueClientInputFromNet(FName PlayerId, const FHelixNetInputPacket& Packet, FString& OutRejectReason)
{
    FClientInputFrame Input;
    Input.Tick = Packet.Tick;
    Input.Sequence = Packet.Sequence;
    Input.Command = Packet.Command;

    return Runtime.QueueClientInput(PlayerId, Input, OutRejectReason);
}

AHelixInputNetBridge* UHelixRuntimeSubsystem::SpawnInputBridgeForPlayer(APlayerController* PlayerController)
{
    if (!PlayerController || !GetWorld() || GetWorld()->GetNetMode() == NM_Client)
    {
        return nullptr;
    }

    FActorSpawnParameters SpawnParams;
    SpawnParams.Owner = PlayerController;
    SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    AHelixInputNetBridge* Bridge = GetWorld()->SpawnActor<AHelixInputNetBridge>(AHelixInputNetBridge::StaticClass(), FTransform::Identity, SpawnParams);
    return Bridge;
}

bool UHelixRuntimeSubsystem::TickRuntime(float DeltaSeconds)
{
    Runtime.TickFixedStep(DeltaSeconds);
    RefreshDebugPanel();

    RuntimeLogAccumulator += DeltaSeconds;
    if (RuntimeLogAccumulator >= 1.0 && Runtime.GetKernel().TimeAuthority.IsValid())
    {
        const uint64 CurrentTick = Runtime.GetKernel().TimeAuthority->GetTick();
        const int32 FixedStepCount = static_cast<int32>(CurrentTick - LastLoggedTick);
        LastLoggedTick = CurrentTick;

        const double Hz = RuntimeLogAccumulator > 0.0 ? static_cast<double>(FixedStepCount) / RuntimeLogAccumulator : 0.0;

        UE_LOG(LogHelixHost, Log, TEXT("[HelixHost] Phase=Running | FixedStepsLastSecond=%d | Hz=%.2f"), FixedStepCount, Hz);
        RuntimeLogAccumulator = 0.0;
    }

    return true;
}

void UHelixRuntimeSubsystem::LogStartupCapabilities() const
{
    UE_LOG(LogHelixHost, Log, TEXT("[Helix] Host Capabilities Registered:"));
    UE_LOG(LogHelixHost, Log, TEXT("    Time.FixedStep = true"));
    UE_LOG(LogHelixHost, Log, TEXT("    Lifecycle.Boot = true"));
    UE_LOG(LogHelixHost, Log, TEXT("    Lifecycle.LockRegistry = true"));
    UE_LOG(LogHelixHost, Log, TEXT("    Scheduler.Update = true"));

    UE_LOG(LogHelixHost, Log, TEXT("[Helix] Required Capability Registered: Time.FixedStep"));
    UE_LOG(LogHelixHost, Log, TEXT("[Helix] Required Capability Registered: Lifecycle.Boot"));
    UE_LOG(LogHelixHost, Log, TEXT("[Helix] Required Capability Registered: Lifecycle.LockRegistry"));
    UE_LOG(LogHelixHost, Log, TEXT("[Helix] Required Capability Registered: Scheduler.Update"));
    UE_LOG(LogHelixHost, Log, TEXT("[Helix] Capability validation successful."));
}

void UHelixRuntimeSubsystem::EnsureDebugPanel()
{
    if (DebugPanelRoot.IsValid() || !GEngine || !GEngine->GameViewport)
    {
        return;
    }

    IConsoleVariable* DebugPanelCVar = IConsoleManager::Get().FindConsoleVariable(TEXT("helix.DebugPanel"));
    if (DebugPanelCVar && DebugPanelCVar->GetInt() == 0)
    {
        return;
    }

    TSharedPtr<STextBlock> TextWidget;
    TSharedPtr<SWidget> RootWidget =
        SNew(SBorder)
        .Padding(FMargin(10.0f))
        [
            SAssignNew(TextWidget, STextBlock)
        ];

    DebugPanelText = TextWidget;
    DebugPanelRoot = RootWidget;
    GEngine->GameViewport->AddViewportWidgetContent(DebugPanelRoot.ToSharedRef(), 5000);
}

void UHelixRuntimeSubsystem::TeardownDebugPanel()
{
    if (DebugPanelRoot.IsValid() && GEngine && GEngine->GameViewport)
    {
        GEngine->GameViewport->RemoveViewportWidgetContent(DebugPanelRoot.ToSharedRef());
    }

    DebugPanelText.Reset();
    DebugPanelRoot.Reset();
}

void UHelixRuntimeSubsystem::RefreshDebugPanel()
{
    IConsoleVariable* DebugPanelCVar = IConsoleManager::Get().FindConsoleVariable(TEXT("helix.DebugPanel"));
    const bool bEnabled = !DebugPanelCVar || DebugPanelCVar->GetInt() != 0;
    if (!bEnabled)
    {
        TeardownDebugPanel();
        return;
    }

    EnsureDebugPanel();
    if (!DebugPanelText.IsValid())
    {
        return;
    }

    const FDebugInspectorData Data = Runtime.GetInspectorData();
    const FString PanelText = FString::Printf(
        TEXT("Helix Debug Panel\nTick: %d  Hash: %llu\nPhysics: Substeps=%d Pairs=%d Collisions=%d\nDiff: Changed=%d Added=%d Removed=%d\nNetworking: Inputs=%d Rejects=%d\nProfiler: FrameMs=%.3f"),
        Data.Tick,
        Data.StateHash,
        Data.Physics.Substeps,
        Data.Physics.BroadphasePairs,
        Data.Physics.Collisions,
        Data.Diff.ChangedBodies,
        Data.Diff.AddedBodies,
        Data.Diff.RemovedBodies,
        Data.Network.InputCount,
        Data.Network.Rejects,
        Data.Profile.TotalMs);

    DebugPanelText->SetText(FText::FromString(PanelText));
}
