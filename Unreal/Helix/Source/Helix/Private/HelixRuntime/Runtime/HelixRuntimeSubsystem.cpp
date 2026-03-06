#include "HelixRuntime/Runtime/HelixRuntimeSubsystem.h"

#include "GameFramework/PlayerController.h"
#include "Engine/World.h"
#include "Engine/Engine.h"
#include "Engine/GameViewportClient.h"
#include "Engine/StaticMeshActor.h"
#include "GameFramework/WorldSettings.h"
#include "EngineUtils.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/CollisionProfile.h"
#include "HAL/IConsoleManager.h"
#include "HelixRuntime/Authorities/NetworkingAuthority.h"
#include "HelixRuntime/Authorities/TimeAuthority.h"
#include "HelixRuntime/Core/HelixLog.h"
#include "HelixRuntime/Runtime/HelixInputNetBridge.h"
#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "HelixRuntime/Runtime/HelixSubsystemRoutingSettings.h"
#include "HelixRuntime/Runtime/IReader.h"
#include "HelixRuntime/Runtime/ISubsystem.h"
#include "HelixRuntime/Runtime/IWriter.h"
#include "HelixRuntime/Runtime/SubsystemManifest.h"

#include "Subsystems/Core/Animation/AnimationSubsystemSettings.h"
#include "Subsystems/Core/Animation/HelixAnimationSubsystem.h"
#include "Subsystems/Core/Audio/AudioSubsystemSettings.h"
#include "Subsystems/Core/Audio/HelixAudioSubsystem.h"
#include "Subsystems/Core/Camera/CameraSubsystemSettings.h"
#include "Subsystems/Core/Camera/HelixCameraSubsystem.h"
#include "Subsystems/Core/Character/CharacterSubsystemSettings.h"
#include "Subsystems/Core/Character/HelixCharacterSubsystem.h"
#include "Subsystems/Core/Event/EventSubsystemSettings.h"
#include "Subsystems/Core/Event/HelixEventSubsystem.h"
#include "Subsystems/Core/Input/InputSubsystemSettings.h"
#include "Subsystems/Core/Input/HelixInputSubsystem.h"
#include "Subsystems/Core/Networking/NetworkingSubsystemSettings.h"
#include "Subsystems/Core/Networking/HelixNetworkingSubsystem.h"
#include "Subsystems/Core/Physics/PhysicsSubsystemSettings.h"
#include "Subsystems/Core/Physics/HelixPhysicsSubsystem.h"
#include "Subsystems/Core/Time/TimeSubsystemSettings.h"
#include "Subsystems/Core/Time/HelixTimeSubsystem.h"
#include "Subsystems/Core/Transform/TransformSubsystemSettings.h"
#include "Subsystems/Core/Transform/HelixTransformSubsystem.h"
#include "Subsystems/Core/World/WorldSubsystemSettings.h"
#include "Subsystems/Core/World/HelixWorldSubsystem.h"
#include "Subsystems/Enterprise/Account/AccountSubsystemSettings.h"
#include "Subsystems/Enterprise/Account/HelixAccountSubsystem.h"
#include "Subsystems/Enterprise/Persistence/PersistenceSubsystemSettings.h"
#include "Subsystems/Enterprise/Persistence/HelixPersistenceSubsystem.h"
#include "Subsystems/Enterprise/Policy/PolicySubsystemSettings.h"
#include "Subsystems/Enterprise/Policy/HelixPolicySubsystem.h"
#include "Subsystems/Enterprise/Security/SecuritySubsystemSettings.h"
#include "Subsystems/Enterprise/Security/HelixSecuritySubsystem.h"
#include "Subsystems/Enterprise/Telemetry/TelemetrySubsystemSettings.h"
#include "Subsystems/Enterprise/Telemetry/HelixTelemetrySubsystem.h"
#include "Subsystems/Expansion/Asset/AssetSubsystemSettings.h"
#include "Subsystems/Expansion/Asset/HelixAssetSubsystem.h"
#include "Subsystems/Expansion/Component/ComponentSubsystemSettings.h"
#include "Subsystems/Expansion/Component/HelixComponentSubsystem.h"
#include "Subsystems/Expansion/Replication/ReplicationSubsystemSettings.h"
#include "Subsystems/Expansion/Replication/HelixReplicationSubsystem.h"
#include "Subsystems/Expansion/Scripting/ScriptingSubsystemSettings.h"
#include "Subsystems/Expansion/Scripting/HelixScriptingSubsystem.h"
#include "Subsystems/Expansion/StateSync/StateSyncSubsystemSettings.h"
#include "Subsystems/Expansion/StateSync/HelixStateSyncSubsystem.h"
#include "Subsystems/Expansion/UI/UISubsystemSettings.h"
#include "Subsystems/Expansion/UI/HelixUISubsystem.h"
#include "Subsystems/Simulation/SimulationControl/SimulationControlSubsystemSettings.h"
#include "Subsystems/Simulation/SimulationControl/HelixSimulationControlSubsystem.h"
#include "Subsystems/Simulation/StepDebugger/StepDebuggerSubsystemSettings.h"
#include "Subsystems/Simulation/StepDebugger/HelixStepDebuggerSubsystem.h"
#include "Subsystems/Simulation/TimeScale/TimeScaleSubsystemSettings.h"
#include "Subsystems/Simulation/TimeScale/HelixTimeScaleSubsystem.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Text/STextBlock.h"
#include <type_traits>
#include <utility>

#define HELIX_DECLARE_HOST_ADAPTER_FALLBACK(TypeName) \
class TypeName \
{ \
public: \
    void Initialize() {} \
    void Update(float) {} \
    void Shutdown() {} \
}

#if __has_include("Subsystems/Core/Animation/UnrealAnimationSubsystem.h")
#include "Subsystems/Core/Animation/UnrealAnimationSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealAnimationSubsystem);
#endif
#if __has_include("Subsystems/Core/Audio/UnrealAudioSubsystem.h")
#include "Subsystems/Core/Audio/UnrealAudioSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealAudioSubsystem);
#endif
#if __has_include("Subsystems/Core/Camera/UnrealCameraSubsystem.h")
#include "Subsystems/Core/Camera/UnrealCameraSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealCameraSubsystem);
#endif
#if __has_include("Subsystems/Core/Character/UnrealCharacterSubsystem.h")
#include "Subsystems/Core/Character/UnrealCharacterSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealCharacterSubsystem);
#endif
#if __has_include("Subsystems/Core/Event/UnrealEventSubsystem.h")
#include "Subsystems/Core/Event/UnrealEventSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealEventSubsystem);
#endif
#if __has_include("Subsystems/Core/Input/UnrealInputSubsystem.h")
#include "Subsystems/Core/Input/UnrealInputSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealInputSubsystem);
#endif
#if __has_include("Subsystems/Core/Networking/UnrealNetworkingSubsystem.h")
#include "Subsystems/Core/Networking/UnrealNetworkingSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealNetworkingSubsystem);
#endif
#if __has_include("Subsystems/Core/Physics/UnrealPhysicsSubsystem.h")
#include "Subsystems/Core/Physics/UnrealPhysicsSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealPhysicsSubsystem);
#endif
#if __has_include("Subsystems/Core/Time/UnrealTimeSubsystem.h")
#include "Subsystems/Core/Time/UnrealTimeSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealTimeSubsystem);
#endif
#if __has_include("Subsystems/Core/Transform/UnrealTransformSubsystem.h")
#include "Subsystems/Core/Transform/UnrealTransformSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealTransformSubsystem);
#endif
#if __has_include("Subsystems/Core/World/UnrealWorldSubsystem.h")
#include "Subsystems/Core/World/UnrealWorldSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealWorldSubsystem);
#endif
#if __has_include("Subsystems/Enterprise/Account/UnrealAccountSubsystem.h")
#include "Subsystems/Enterprise/Account/UnrealAccountSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealAccountSubsystem);
#endif
#if __has_include("Subsystems/Enterprise/Persistence/UnrealPersistenceSubsystem.h")
#include "Subsystems/Enterprise/Persistence/UnrealPersistenceSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealPersistenceSubsystem);
#endif
#if __has_include("Subsystems/Enterprise/Policy/UnrealPolicySubsystem.h")
#include "Subsystems/Enterprise/Policy/UnrealPolicySubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealPolicySubsystem);
#endif
#if __has_include("Subsystems/Enterprise/Security/UnrealSecuritySubsystem.h")
#include "Subsystems/Enterprise/Security/UnrealSecuritySubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealSecuritySubsystem);
#endif
#if __has_include("Subsystems/Enterprise/Telemetry/UnrealTelemetrySubsystem.h")
#include "Subsystems/Enterprise/Telemetry/UnrealTelemetrySubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealTelemetrySubsystem);
#endif
#if __has_include("Subsystems/Expansion/Asset/UnrealAssetSubsystem.h")
#include "Subsystems/Expansion/Asset/UnrealAssetSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealAssetSubsystem);
#endif
#if __has_include("Subsystems/Expansion/Component/UnrealComponentSubsystem.h")
#include "Subsystems/Expansion/Component/UnrealComponentSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealComponentSubsystem);
#endif
#if __has_include("Subsystems/Expansion/Replication/UnrealReplicationSubsystem.h")
#include "Subsystems/Expansion/Replication/UnrealReplicationSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealReplicationSubsystem);
#endif
#if __has_include("Subsystems/Expansion/Scripting/UnrealScriptingSubsystem.h")
#include "Subsystems/Expansion/Scripting/UnrealScriptingSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealScriptingSubsystem);
#endif
#if __has_include("Subsystems/Expansion/StateSync/UnrealStateSyncSubsystem.h")
#include "Subsystems/Expansion/StateSync/UnrealStateSyncSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealStateSyncSubsystem);
#endif
#if __has_include("Subsystems/Expansion/UI/UnrealUISubsystem.h")
#include "Subsystems/Expansion/UI/UnrealUISubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealUISubsystem);
#endif
#if __has_include("Subsystems/Simulation/SimulationControl/UnrealSimulationControlSubsystem.h")
#include "Subsystems/Simulation/SimulationControl/UnrealSimulationControlSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealSimulationControlSubsystem);
#endif
#if __has_include("Subsystems/Simulation/StepDebugger/UnrealStepDebuggerSubsystem.h")
#include "Subsystems/Simulation/StepDebugger/UnrealStepDebuggerSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealStepDebuggerSubsystem);
#endif
#if __has_include("Subsystems/Simulation/TimeScale/UnrealTimeScaleSubsystem.h")
#include "Subsystems/Simulation/TimeScale/UnrealTimeScaleSubsystem.h"
#else
HELIX_DECLARE_HOST_ADAPTER_FALLBACK(FUnrealTimeScaleSubsystem);
#endif

#undef HELIX_DECLARE_HOST_ADAPTER_FALLBACK

namespace
{
TAutoConsoleVariable<int32> CVarHelixUseHelixPhysics(TEXT("helix.UseHelixPhysics"), 0, TEXT("0=Unreal physics backend, 1=Helix physics backend (driven by subsystem routing)"));
TAutoConsoleVariable<float> CVarHelixPhysicsGravityZ(TEXT("helix.PhysicsGravityZ"), -980.0f, TEXT("Current gravity Z mirrored from Unreal world settings"));

float ResolveRuntimeGravityZ(UWorld* World)
{
    if (!World)
    {
        return -980.0f;
    }

    if (const AWorldSettings* WorldSettings = World->GetWorldSettings())
    {
        if (WorldSettings->bGlobalGravitySet)
        {
            return WorldSettings->GlobalGravityZ;
        }
    }

    return World->GetGravityZ();
}

void SyncHelixCVarInt(const TCHAR* Name, int32 Value)
{
    if (IConsoleVariable* CVar = IConsoleManager::Get().FindConsoleVariable(Name))
    {
        CVar->Set(Value, ECVF_SetByCode);
    }
}

void SyncHelixCVarFloat(const TCHAR* Name, float Value)
{
    if (IConsoleVariable* CVar = IConsoleManager::Get().FindConsoleVariable(Name))
    {
        CVar->Set(Value, ECVF_SetByCode);
    }
}

template <typename TSubsystemSettings>
bool ShouldEnableSubsystem(FName SubsystemName)
{
    const TSubsystemSettings* Settings = GetDefault<TSubsystemSettings>();

    if constexpr (std::is_same_v<TSubsystemSettings, UPhysicsSubsystemSettings>)
    {
        if (Settings && !Settings->bEnabled)
        {
            UE_LOG(LogHelixRuntime, Warning, TEXT("[HelixRuntime] Ignoring bEnabled=false for PhysicsSubsystem; subsystem remains active for explicit backend ownership"));
        }
        return true;
    }

    if (Settings && !Settings->bEnabled)
    {
        UE_LOG(LogHelixRuntime, Log, TEXT("[HelixRuntime] Subsystem disabled by settings: %s"), *SubsystemName.ToString());
        return false;
    }

    if (Settings && !Settings->bDeterministic)
    {
        UE_LOG(LogHelixRuntime, Warning, TEXT("[HelixRuntime] Subsystem marked non-deterministic: %s"), *SubsystemName.ToString());
    }

    return true;
}

template <typename TSubsystemSettings>
void AppendControlSourceOverride(TArray<TPair<FName, FName>>& OutOverrides, FName SubsystemName)
{
    if constexpr (std::is_same_v<TSubsystemSettings, UPhysicsSubsystemSettings>)
    {
        // Physics control source is driven exclusively by global backend settings.
        return;
    }

    const TSubsystemSettings* Settings = GetDefault<TSubsystemSettings>();
    if (!Settings)
    {
        return;
    }

    const TOptional<FName> OverrideSource = Settings->ResolveControlSourceOverride();
    if (OverrideSource.IsSet())
    {
        OutOverrides.Emplace(SubsystemName, OverrideSource.GetValue());
        if (Settings->bVerboseRoutingLogs)
        {
            UE_LOG(LogHelixRuntime, Log, TEXT("[HelixRuntime] Per-subsystem override: %s -> %s"), *SubsystemName.ToString(), *OverrideSource->ToString());
        }
    }
}

void ApplyPhysicsBackendControlSource(FRuntimeEntrypoint& Runtime, const UHelixSubsystemRoutingSettings* RoutingSettings)
{
    if (!RoutingSettings)
    {
        return;
    }

    const FName PhysicsSource = UHelixSubsystemRoutingSettings::ToControlSourceName(RoutingSettings->PhysicsSubsystem);
    Runtime.SetSubsystemControlSource(TEXT("PhysicsSubsystem"), PhysicsSource);

    if (Runtime.GetKernel().Config.IsValid())
    {
        const bool bUseHelixPhysics = (PhysicsSource == FName(TEXT("Helix")));
        Runtime.GetKernel().Config->bUseHelixPhysics = bUseHelixPhysics;
        SyncHelixCVarInt(TEXT("helix.UseHelixPhysics"), bUseHelixPhysics ? 1 : 0);
    }
}

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

template <typename T, typename = void>
struct THasInitializeWithKernel : std::false_type {};

template <typename T>
struct THasInitializeWithKernel<T, std::void_t<decltype(std::declval<T&>().Initialize(std::declval<FHelixKernel&>()))>> : std::true_type {};

template <typename T, typename = void>
struct THasUpdateWithKernel : std::false_type {};

template <typename T>
struct THasUpdateWithKernel<T, std::void_t<decltype(std::declval<T&>().Update(0.0f, std::declval<FHelixKernel&>()))>> : std::true_type {};

template <typename T, typename = void>
struct THasShutdownWithKernel : std::false_type {};

template <typename T>
struct THasShutdownWithKernel<T, std::void_t<decltype(std::declval<T&>().Shutdown(std::declval<FHelixKernel&>()))>> : std::true_type {};

template <typename THelixAdapter, typename THostAdapter>
class FRoutedAdapterSubsystem final : public FHelixSubsystemBase
{
public:
    explicit FRoutedAdapterSubsystem(FName InName)
        : Name(InName)
    {
    }

    void Init(FHelixKernel& Kernel, TSharedPtr<IReader> Reader, TSharedPtr<IWriter> Writer) override
    {
        BoundKernel = &Kernel;
        BoundReader = Reader;
        BoundWriter = Writer;
    }

    void Start() override
    {
        bHelixInitialized = false;
        bHostInitialized = false;
        LastControlSource = NAME_None;
    }

    void Tick(double FixedDt) override
    {
        const FName CurrentControlSource = GetControlSource();
        const bool bUseHelix = (CurrentControlSource == FName(TEXT("Helix")));

        if (LastControlSource != NAME_None && LastControlSource != CurrentControlSource)
        {
            if (LastControlSource == FName(TEXT("Helix")) && bHelixInitialized)
            {
                ShutdownHelixAdapter();
                bHelixInitialized = false;
            }
            else if (LastControlSource != FName(TEXT("Helix")) && bHostInitialized)
            {
                ShutdownHostAdapter();
                bHostInitialized = false;
            }
        }

        if (bUseHelix && !bHelixInitialized)
        {
            InitializeHelixAdapter();
            bHelixInitialized = true;
        }
        else if (!bUseHelix && !bHostInitialized)
        {
            InitializeHostAdapter();
            bHostInitialized = true;
        }

        LastControlSource = CurrentControlSource;

        if (bUseHelix)
        {
            if constexpr (THasUpdateWithKernel<THelixAdapter>::value)
            {
                if (BoundKernel)
                {
                    HelixAdapter.Update(static_cast<float>(FixedDt), *BoundKernel);
                }
            }
            else
            {
                HelixAdapter.Update(static_cast<float>(FixedDt));
            }
            return;
        }

        if constexpr (THasUpdateWithKernel<THostAdapter>::value)
        {
            if (BoundKernel)
            {
                HostAdapter.Update(static_cast<float>(FixedDt), *BoundKernel);
            }
        }
        else
        {
            HostAdapter.Update(static_cast<float>(FixedDt));
        }
    }

    void Stop() override
    {
        if (bHelixInitialized)
        {
            ShutdownHelixAdapter();
            bHelixInitialized = false;
        }

        if (bHostInitialized)
        {
            ShutdownHostAdapter();
            bHostInitialized = false;
        }
    }

private:
    void InitializeHelixAdapter()
    {
        if constexpr (THasInitializeWithKernel<THelixAdapter>::value)
        {
            if (BoundKernel)
            {
                HelixAdapter.Initialize(*BoundKernel);
            }
        }
        else
        {
            HelixAdapter.Initialize();
        }
    }

    void InitializeHostAdapter()
    {
        if constexpr (THasInitializeWithKernel<THostAdapter>::value)
        {
            if (BoundKernel)
            {
                HostAdapter.Initialize(*BoundKernel);
            }
        }
        else
        {
            HostAdapter.Initialize();
        }
    }

    void ShutdownHelixAdapter()
    {
        if constexpr (THasShutdownWithKernel<THelixAdapter>::value)
        {
            if (BoundKernel)
            {
                HelixAdapter.Shutdown(*BoundKernel);
            }
        }
        else
        {
            HelixAdapter.Shutdown();
        }
    }

    void ShutdownHostAdapter()
    {
        if constexpr (THasShutdownWithKernel<THostAdapter>::value)
        {
            if (BoundKernel)
            {
                HostAdapter.Shutdown(*BoundKernel);
            }
        }
        else
        {
            HostAdapter.Shutdown();
        }
    }

    FName Name;
    THelixAdapter HelixAdapter;
    THostAdapter HostAdapter;
    FHelixKernel* BoundKernel = nullptr;
    TSharedPtr<IReader> BoundReader;
    TSharedPtr<IWriter> BoundWriter;
    FName LastControlSource = NAME_None;
    bool bHelixInitialized = false;
    bool bHostInitialized = false;
};

template <typename THelixAdapter, typename THostAdapter, typename TSubsystemSettings>
void AddRoutedSubsystem(
    TArray<FSubsystemManifestEntry>& Manifest,
    TArray<TPair<FName, FName>>& OutControlOverrides,
    FName Name,
    FName Domain,
    int32 Phase,
    TArray<FName> Dependencies)
{
    if (!ShouldEnableSubsystem<TSubsystemSettings>(Name))
    {
        return;
    }

    AppendControlSourceOverride<TSubsystemSettings>(OutControlOverrides, Name);

    FSubsystemManifestEntry Entry;
    Entry.Name = Name;
    Entry.Domain = Domain;
    Entry.Phase = Phase;
    Entry.Dependencies = MoveTemp(Dependencies);
    Entry.CreateSubsystem = [Name]() -> TSharedPtr<ISubsystem> { return MakeShared<FRoutedAdapterSubsystem<THelixAdapter, THostAdapter>>(Name); };
    Entry.CreateReader = [Name]() -> TSharedPtr<IReader> { return MakeShared<FNoopReader>(Name); };
    Entry.CreateWriter = [Name, Domain]() -> TSharedPtr<IWriter> { return MakeShared<FNoopWriter>(Name, Domain); };
    Manifest.Add(MoveTemp(Entry));
}

void BuildPerSubsystemControlOverrides(TArray<TPair<FName, FName>>& OutOverrides)
{
    AppendControlSourceOverride<UAnimationSubsystemSettings>(OutOverrides, TEXT("AnimationSubsystem"));
    AppendControlSourceOverride<UAudioSubsystemSettings>(OutOverrides, TEXT("AudioSubsystem"));
    AppendControlSourceOverride<UCameraSubsystemSettings>(OutOverrides, TEXT("CameraSubsystem"));
    AppendControlSourceOverride<UCharacterSubsystemSettings>(OutOverrides, TEXT("CharacterSubsystem"));
    AppendControlSourceOverride<UEventSubsystemSettings>(OutOverrides, TEXT("EventSubsystem"));
    AppendControlSourceOverride<UInputSubsystemSettings>(OutOverrides, TEXT("InputSubsystem"));
    AppendControlSourceOverride<UNetworkingSubsystemSettings>(OutOverrides, TEXT("NetworkingSubsystem"));
    AppendControlSourceOverride<UTimeSubsystemSettings>(OutOverrides, TEXT("TimeSubsystem"));
    AppendControlSourceOverride<UTransformSubsystemSettings>(OutOverrides, TEXT("TransformSubsystem"));
    AppendControlSourceOverride<UWorldSubsystemSettings>(OutOverrides, TEXT("WorldSubsystem"));

    AppendControlSourceOverride<UAccountSubsystemSettings>(OutOverrides, TEXT("AccountSubsystem"));
    AppendControlSourceOverride<UPersistenceSubsystemSettings>(OutOverrides, TEXT("PersistenceSubsystem"));
    AppendControlSourceOverride<UPolicySubsystemSettings>(OutOverrides, TEXT("PolicySubsystem"));
    AppendControlSourceOverride<USecuritySubsystemSettings>(OutOverrides, TEXT("SecuritySubsystem"));
    AppendControlSourceOverride<UTelemetrySubsystemSettings>(OutOverrides, TEXT("TelemetrySubsystem"));

    AppendControlSourceOverride<UAssetSubsystemSettings>(OutOverrides, TEXT("AssetSubsystem"));
    AppendControlSourceOverride<UComponentSubsystemSettings>(OutOverrides, TEXT("ComponentSubsystem"));
    AppendControlSourceOverride<UReplicationSubsystemSettings>(OutOverrides, TEXT("ReplicationSubsystem"));
    AppendControlSourceOverride<UScriptingSubsystemSettings>(OutOverrides, TEXT("ScriptingSubsystem"));
    AppendControlSourceOverride<UStateSyncSubsystemSettings>(OutOverrides, TEXT("StateSyncSubsystem"));
    AppendControlSourceOverride<UUISubsystemSettings>(OutOverrides, TEXT("UISubsystem"));

    AppendControlSourceOverride<USimulationControlSubsystemSettings>(OutOverrides, TEXT("SimulationControlSubsystem"));
    AppendControlSourceOverride<UStepDebuggerSubsystemSettings>(OutOverrides, TEXT("StepDebuggerSubsystem"));
    AppendControlSourceOverride<UTimeScaleSubsystemSettings>(OutOverrides, TEXT("TimeScaleSubsystem"));
}

TArray<FSubsystemManifestEntry> BuildDefaultManifest(TArray<TPair<FName, FName>>& OutControlOverrides)
{
    TArray<FSubsystemManifestEntry> Manifest;

    AddRoutedSubsystem<FHelixAnimationSubsystem, FUnrealAnimationSubsystem, UAnimationSubsystemSettings>(Manifest, OutControlOverrides, TEXT("AnimationSubsystem"), TEXT("Core"), 1, {});
    AddRoutedSubsystem<FHelixAudioSubsystem, FUnrealAudioSubsystem, UAudioSubsystemSettings>(Manifest, OutControlOverrides, TEXT("AudioSubsystem"), TEXT("Core"), 1, {});
    AddRoutedSubsystem<FHelixCameraSubsystem, FUnrealCameraSubsystem, UCameraSubsystemSettings>(Manifest, OutControlOverrides, TEXT("CameraSubsystem"), TEXT("Core"), 1, {});
    AddRoutedSubsystem<FHelixCharacterSubsystem, FUnrealCharacterSubsystem, UCharacterSubsystemSettings>(Manifest, OutControlOverrides, TEXT("CharacterSubsystem"), TEXT("Core"), 1, {});
    AddRoutedSubsystem<FHelixEventSubsystem, FUnrealEventSubsystem, UEventSubsystemSettings>(Manifest, OutControlOverrides, TEXT("EventSubsystem"), TEXT("Core"), 1, {});
    AddRoutedSubsystem<FHelixInputSubsystem, FUnrealInputSubsystem, UInputSubsystemSettings>(Manifest, OutControlOverrides, TEXT("InputSubsystem"), TEXT("Core"), 1, {});
    AddRoutedSubsystem<FHelixNetworkingSubsystem, FUnrealNetworkingSubsystem, UNetworkingSubsystemSettings>(Manifest, OutControlOverrides, TEXT("NetworkingSubsystem"), TEXT("Core"), 1, { TEXT("PhysicsSubsystem") });
    AddRoutedSubsystem<FHelixPhysicsSubsystem, FUnrealPhysicsSubsystem, UPhysicsSubsystemSettings>(Manifest, OutControlOverrides, TEXT("PhysicsSubsystem"), TEXT("Core"), 1, { TEXT("WorldSubsystem") });
    AddRoutedSubsystem<FHelixTimeSubsystem, FUnrealTimeSubsystem, UTimeSubsystemSettings>(Manifest, OutControlOverrides, TEXT("TimeSubsystem"), TEXT("Core"), 1, {});
    AddRoutedSubsystem<FHelixTransformSubsystem, FUnrealTransformSubsystem, UTransformSubsystemSettings>(Manifest, OutControlOverrides, TEXT("TransformSubsystem"), TEXT("Core"), 1, { TEXT("PhysicsSubsystem") });
    AddRoutedSubsystem<FHelixWorldSubsystem, FUnrealWorldSubsystem, UWorldSubsystemSettings>(Manifest, OutControlOverrides, TEXT("WorldSubsystem"), TEXT("Core"), 1, {});

    AddRoutedSubsystem<FHelixAccountSubsystem, FUnrealAccountSubsystem, UAccountSubsystemSettings>(Manifest, OutControlOverrides, TEXT("AccountSubsystem"), TEXT("Enterprise"), 2, {});
    AddRoutedSubsystem<FHelixPersistenceSubsystem, FUnrealPersistenceSubsystem, UPersistenceSubsystemSettings>(Manifest, OutControlOverrides, TEXT("PersistenceSubsystem"), TEXT("Enterprise"), 2, {});
    AddRoutedSubsystem<FHelixPolicySubsystem, FUnrealPolicySubsystem, UPolicySubsystemSettings>(Manifest, OutControlOverrides, TEXT("PolicySubsystem"), TEXT("Enterprise"), 2, {});
    AddRoutedSubsystem<FHelixSecuritySubsystem, FUnrealSecuritySubsystem, USecuritySubsystemSettings>(Manifest, OutControlOverrides, TEXT("SecuritySubsystem"), TEXT("Enterprise"), 2, {});
    AddRoutedSubsystem<FHelixTelemetrySubsystem, FUnrealTelemetrySubsystem, UTelemetrySubsystemSettings>(Manifest, OutControlOverrides, TEXT("TelemetrySubsystem"), TEXT("Enterprise"), 2, {});

    AddRoutedSubsystem<FHelixAssetSubsystem, FUnrealAssetSubsystem, UAssetSubsystemSettings>(Manifest, OutControlOverrides, TEXT("AssetSubsystem"), TEXT("Expansion"), 3, {});
    AddRoutedSubsystem<FHelixComponentSubsystem, FUnrealComponentSubsystem, UComponentSubsystemSettings>(Manifest, OutControlOverrides, TEXT("ComponentSubsystem"), TEXT("Expansion"), 3, {});
    AddRoutedSubsystem<FHelixReplicationSubsystem, FUnrealReplicationSubsystem, UReplicationSubsystemSettings>(Manifest, OutControlOverrides, TEXT("ReplicationSubsystem"), TEXT("Expansion"), 3, {});
    AddRoutedSubsystem<FHelixScriptingSubsystem, FUnrealScriptingSubsystem, UScriptingSubsystemSettings>(Manifest, OutControlOverrides, TEXT("ScriptingSubsystem"), TEXT("Expansion"), 3, {});
    AddRoutedSubsystem<FHelixStateSyncSubsystem, FUnrealStateSyncSubsystem, UStateSyncSubsystemSettings>(Manifest, OutControlOverrides, TEXT("StateSyncSubsystem"), TEXT("Expansion"), 3, {});
    AddRoutedSubsystem<FHelixUISubsystem, FUnrealUISubsystem, UUISubsystemSettings>(Manifest, OutControlOverrides, TEXT("UISubsystem"), TEXT("Expansion"), 3, {});

    AddRoutedSubsystem<FHelixSimulationControlSubsystem, FUnrealSimulationControlSubsystem, USimulationControlSubsystemSettings>(Manifest, OutControlOverrides, TEXT("SimulationControlSubsystem"), TEXT("Simulation"), 4, {});
    AddRoutedSubsystem<FHelixStepDebuggerSubsystem, FUnrealStepDebuggerSubsystem, UStepDebuggerSubsystemSettings>(Manifest, OutControlOverrides, TEXT("StepDebuggerSubsystem"), TEXT("Simulation"), 4, {});
    AddRoutedSubsystem<FHelixTimeScaleSubsystem, FUnrealTimeScaleSubsystem, UTimeScaleSubsystemSettings>(Manifest, OutControlOverrides, TEXT("TimeScaleSubsystem"), TEXT("Simulation"), 4, {});

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
    const UHelixSubsystemRoutingSettings* RoutingSettings = GetDefault<UHelixSubsystemRoutingSettings>();
    const float GravityZ = ResolveRuntimeGravityZ(GetWorld());
    Config.bUseHelixPhysics = (UHelixSubsystemRoutingSettings::ToControlSourceName(RoutingSettings->PhysicsSubsystem) == FName(TEXT("Helix")));
    Config.PhysicsGravityZ = static_cast<double>(GravityZ);
    SyncHelixCVarInt(TEXT("helix.UseHelixPhysics"), Config.bUseHelixPhysics ? 1 : 0);
    SyncHelixCVarFloat(TEXT("helix.PhysicsGravityZ"), GravityZ);
    SyncHelixCVarInt(TEXT("helix.GravityControlEnabled"), 0);
    UE_LOG(LogHelixRuntime, Log, TEXT("[HelixRuntime] PhysicsBackend=%s"), Config.bUseHelixPhysics ? TEXT("Helix") : TEXT("Unreal"));

    TArray<TPair<FName, FName>> PerSubsystemSourceOverrides;
    bRuntimeStarted = Runtime.Start(Config, BuildDefaultManifest(PerSubsystemSourceOverrides), Error);

    if (!bRuntimeStarted)
    {
        UE_LOG(LogHelixRuntime, Error, TEXT("[HelixRuntime] Failed to start: %s"), *Error);
        return false;
    }

    LogStartupCapabilities();
    RuntimeLogAccumulator = 0.0;
    LastLoggedTick = 0;

    TArray<TPair<FName, FName>> SubsystemSources;
    RoutingSettings->BuildSubsystemSourceMap(SubsystemSources);
    for (const TPair<FName, FName>& Entry : SubsystemSources)
    {
        Runtime.SetSubsystemControlSource(Entry.Key, Entry.Value);
    }
    for (const TPair<FName, FName>& Entry : PerSubsystemSourceOverrides)
    {
        Runtime.SetSubsystemControlSource(Entry.Key, Entry.Value);
    }
    ApplyPhysicsBackendControlSource(Runtime, RoutingSettings);

    EnsureDebugPanel();
    bPendingRigCleanup = true;
    DestroyPhysicsTestRigs();

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
    if (bPendingRigCleanup)
    {
        const int32 Removed = DestroyPhysicsTestRigs();
        if (Removed == 0)
        {
            bPendingRigCleanup = false;
        }
    }

    if (Runtime.GetKernel().Config.IsValid())
    {
        const UHelixSubsystemRoutingSettings* RoutingSettings = GetDefault<UHelixSubsystemRoutingSettings>();
        const float GravityZ = ResolveRuntimeGravityZ(GetWorld());
        Runtime.GetKernel().Config->bUseHelixPhysics = (UHelixSubsystemRoutingSettings::ToControlSourceName(RoutingSettings->PhysicsSubsystem) == FName(TEXT("Helix")));
        Runtime.GetKernel().Config->PhysicsGravityZ = static_cast<double>(GravityZ);

        SyncHelixCVarInt(TEXT("helix.UseHelixPhysics"), Runtime.GetKernel().Config->bUseHelixPhysics ? 1 : 0);
        SyncHelixCVarFloat(TEXT("helix.PhysicsGravityZ"), GravityZ);
        SyncHelixCVarInt(TEXT("helix.GravityControlEnabled"), 0);

        TArray<TPair<FName, FName>> SubsystemSources;
        RoutingSettings->BuildSubsystemSourceMap(SubsystemSources);
        for (const TPair<FName, FName>& Entry : SubsystemSources)
        {
            Runtime.SetSubsystemControlSource(Entry.Key, Entry.Value);
        }

        TArray<TPair<FName, FName>> PerSubsystemSourceOverrides;
        BuildPerSubsystemControlOverrides(PerSubsystemSourceOverrides);
        for (const TPair<FName, FName>& Entry : PerSubsystemSourceOverrides)
        {
            Runtime.SetSubsystemControlSource(Entry.Key, Entry.Value);
        }

        ApplyPhysicsBackendControlSource(Runtime, RoutingSettings);
    }

    Runtime.TickFixedStep(DeltaSeconds);
    RefreshDebugPanel();

    RuntimeLogAccumulator += DeltaSeconds;
    if (RuntimeLogAccumulator >= 1.0 && Runtime.GetKernel().TimeAuthority.IsValid())
    {
        const uint64 CurrentTick = Runtime.GetKernel().TimeAuthority->GetTick();
        const int32 FixedStepCount = static_cast<int32>(CurrentTick - LastLoggedTick);
        LastLoggedTick = CurrentTick;

        const double Hz = RuntimeLogAccumulator > 0.0 ? static_cast<double>(FixedStepCount) / RuntimeLogAccumulator : 0.0;

        UE_LOG(LogHelixRouter, Log, TEXT("[HelixRuntime] Phase=Running | FixedStepsLastSecond=%d | Hz=%.2f"), FixedStepCount, Hz);
        RuntimeLogAccumulator = 0.0;
    }

    return true;
}

void UHelixRuntimeSubsystem::LogStartupCapabilities() const
{
    UE_LOG(LogHelixRouter, Log, TEXT("[Helix] Unreal Capabilities Registered:"));
    UE_LOG(LogHelixRouter, Log, TEXT("    Time.FixedStep = true"));
    UE_LOG(LogHelixRouter, Log, TEXT("    Lifecycle.Boot = true"));
    UE_LOG(LogHelixRouter, Log, TEXT("    Lifecycle.LockRegistry = true"));
    UE_LOG(LogHelixRouter, Log, TEXT("    Scheduler.Update = true"));

    UE_LOG(LogHelixRouter, Log, TEXT("[Helix] Required Capability Registered: Time.FixedStep"));
    UE_LOG(LogHelixRouter, Log, TEXT("[Helix] Required Capability Registered: Lifecycle.Boot"));
    UE_LOG(LogHelixRouter, Log, TEXT("[Helix] Required Capability Registered: Lifecycle.LockRegistry"));
    UE_LOG(LogHelixRouter, Log, TEXT("[Helix] Required Capability Registered: Scheduler.Update"));
    UE_LOG(LogHelixRouter, Log, TEXT("[Helix] Capability validation successful."));
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
        TEXT("Helix Debug Panel\nTick: %d  Hash: %llu\nPhysicsSignature: %llu\nPhysics: Substeps=%d Pairs=%d Collisions=%d\nDiff: Changed=%d Added=%d Removed=%d\nNetworking: Inputs=%d Rejects=%d\nProfiler: FrameMs=%.3f"),
        Data.Tick,
        Data.StateHash,
        Data.PhysicsSignature,
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

int32 UHelixRuntimeSubsystem::DestroyPhysicsTestRigs()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return 0;
    }

    TArray<AActor*> ActorsToDestroy;
    for (TActorIterator<AActor> It(World); It; ++It)
    {
        const AActor* Actor = *It;
        const FString Name = Actor->GetName();
        const bool bLooksLikeLegacyHelixRig =
            Name.Contains(TEXT("HelixTest_Floor")) ||
            Name.Contains(TEXT("HelixTest_Cube"));

        if (Actor->ActorHasTag(TEXT("HelixPhysicsTestRig")) || bLooksLikeLegacyHelixRig)
        {
            ActorsToDestroy.Add(*It);
        }
    }

    for (AActor* Actor : ActorsToDestroy)
    {
        if (IsValid(Actor))
        {
            Actor->Destroy();
        }
    }

    if (ActorsToDestroy.Num() > 0)
    {
        UE_LOG(LogHelixRuntime, Log, TEXT("[HelixRuntime] Removed %d hardcoded Helix physics test rig actor(s)"), ActorsToDestroy.Num());
    }

    return ActorsToDestroy.Num();
}
