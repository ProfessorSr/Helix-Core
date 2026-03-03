#include "HelixRuntime/Runtime/RuntimeEntrypoint.h"

#include "HelixRuntime/Authorities/DomainSchemaAuthority.h"
#include "HelixRuntime/Authorities/EventAuthority.h"
#include "HelixRuntime/Authorities/GameplayAuthority.h"
#include "HelixRuntime/Authorities/NetworkingAuthority.h"
#include "HelixRuntime/Authorities/ProfilerAuthority.h"
#include "HelixRuntime/Authorities/ReplayCertificationAuthority.h"
#include "HelixRuntime/Authorities/TimeAuthority.h"
#include "HelixRuntime/Core/Boot.h"
#include "HelixRuntime/Core/HelixLog.h"
#include "HelixRuntime/Core/Scheduler.h"
#include "HelixRuntime/Runtime/IReader.h"
#include "HelixRuntime/Runtime/IWriter.h"
#include "HelixRuntime/Runtime/RuntimeHost.h"
#include "HelixRuntime/Runtime/ISubsystem.h"
#include "HelixRuntime/Simulation/PhysicsPipeline.h"
#include "HelixRuntime/Simulation/SnapshotDiff.h"
#include "HelixRuntime/Simulation/WorldGraph.h"
#include "HelixRuntime/Simulation/ContentValidator.h"
#include "HAL/IConsoleManager.h"

namespace
{
TAutoConsoleVariable<int32> CVarHelixDebugPanel(TEXT("helix.DebugPanel"), 1, TEXT("Enable Helix debug payload generation"));
TAutoConsoleVariable<int32> CVarHelixProfile(TEXT("helix.Profile"), 1, TEXT("Enable Helix subsystem profiling"));
TAutoConsoleVariable<int32> CVarHelixAuthoritativeNet(TEXT("helix.AuthoritativeNet"), 1, TEXT("Enable Helix authoritative networking"));
}

bool FRuntimeEntrypoint::Start(const FHelixConfig& InitialConfig, const TArray<FSubsystemManifestEntry>& Manifest, FString& OutError)
{
    if (bStarted)
    {
        return true;
    }

    UE_LOG(LogHelixRuntime, Log, TEXT("[RuntimeEntrypoint] Start"));
    Kernel = FHelixBootstrap::BuildKernel(InitialConfig);

    Kernel.TimeAuthority->Initialize(Kernel.Config->FixedStep());
    Kernel.DomainSchemaAuthority->Initialize({ TEXT("Core"), TEXT("Simulation"), TEXT("Networking") });
    Kernel.EventAuthority->Initialize();
    Kernel.NetworkingAuthority->Initialize(*Kernel.Config);
    Kernel.GameplayAuthority->Initialize(Kernel.NetworkingAuthority);
    Kernel.ProfilerAuthority->Initialize(CVarHelixProfile.GetValueOnAnyThread() != 0 && Kernel.Config->bProfileEnabled);
    Kernel.ReplayCertificationAuthority->Initialize();
    UE_LOG(LogHelixRuntime, Log, TEXT("[RuntimeEntrypoint] Kernel ready"));

    Host = MakeShared<FRuntimeHost>();
    if (!Host->Start(Kernel, Manifest, OutError))
    {
        UE_LOG(LogHelixRuntime, Error, TEXT("[RuntimeEntrypoint] Failed start: %s"), *OutError);
        Stop();
        return false;
    }

    Scheduler = MakeShared<FDeterministicFixedStepScheduler>(Kernel, [this](double FixedDt)
    {
        TickOneStep(FixedDt);
    });
    Scheduler->Reset();

    bStarted = true;
    return true;
}

void FRuntimeEntrypoint::Stop()
{
    if (!bStarted)
    {
        return;
    }

    if (Host.IsValid())
    {
        Host->Stop(Kernel);
    }

    if (Kernel.ReplayCertificationAuthority.IsValid())
    {
        Kernel.ReplayCertificationAuthority->Shutdown();
    }
    if (Kernel.ProfilerAuthority.IsValid())
    {
        Kernel.ProfilerAuthority->Shutdown();
    }
    if (Kernel.NetworkingAuthority.IsValid())
    {
        Kernel.NetworkingAuthority->Shutdown();
    }
    if (Kernel.GameplayAuthority.IsValid())
    {
        Kernel.GameplayAuthority->Shutdown();
    }
    if (Kernel.EventAuthority.IsValid())
    {
        Kernel.EventAuthority->Shutdown();
    }
    if (Kernel.DomainSchemaAuthority.IsValid())
    {
        Kernel.DomainSchemaAuthority->Shutdown();
    }
    if (Kernel.TimeAuthority.IsValid())
    {
        Kernel.TimeAuthority->Shutdown();
    }

    if (Kernel.Simulation.IsValid())
    {
        Kernel.Simulation->Bodies.Reset();
        Kernel.Simulation->Constraints.Reset();
    }

    if (Scheduler.IsValid())
    {
        Scheduler->Reset();
    }

    bStarted = false;
    UE_LOG(LogHelixRuntime, Log, TEXT("[RuntimeEntrypoint] Stop complete"));
}

void FRuntimeEntrypoint::TickFixedStep(double Dt)
{
    if (!bStarted || !Kernel.Config.IsValid())
    {
        return;
    }

    Scheduler->Advance(Dt);
}

void FRuntimeEntrypoint::TickOneStep(double FixedDt)
{
    if (Kernel.ProfilerAuthority->IsEnabled())
    {
        Kernel.ProfilerAuthority->BeginFrame();
    }

    FSimulationState Previous = *Kernel.Simulation;

    Kernel.TimeAuthority->Advance();
    Kernel.EventAuthority->ProcessTick();
    UE_LOG(LogHelixAuthority, VeryVerbose, TEXT("[EventAuthority] ProcessTick=%llu | Events=%d"), Kernel.TimeAuthority->GetTick(), Kernel.EventAuthority->GetEventsThisTick());
    if (CVarHelixAuthoritativeNet.GetValueOnAnyThread() != 0 && Kernel.Config->bAuthoritativeNetEnabled)
    {
        Kernel.GameplayAuthority->ProcessTick();
        UE_LOG(LogHelixAuthority, VeryVerbose, TEXT("[GameplayAuthority] ProcessTick=%llu | InputFrames=%d"), Kernel.TimeAuthority->GetTick(), Kernel.GameplayAuthority->GetProcessedInputsThisTick());
    }

    for (const FRuntimeSubsystemInstance& Instance : Host->GetOrdered())
    {
        if (!Instance.Subsystem.IsValid())
        {
            continue;
        }

        const double Start = FPlatformTime::Seconds();
        if (Instance.Reader.IsValid() && Instance.Subsystem->GetControlSource() == TEXT("Host"))
        {
            Instance.Reader->Tick(FixedDt);
        }

        Instance.Subsystem->Tick(FixedDt);

        if (Instance.Writer.IsValid())
        {
            Instance.Writer->Tick(FixedDt);
        }

        const double ElapsedMs = (FPlatformTime::Seconds() - Start) * 1000.0;
        Kernel.ProfilerAuthority->AddSubsystemTime(Instance.Manifest.Name, ElapsedMs);
    }
    UE_LOG(LogHelixScheduler, VeryVerbose, TEXT("[Scheduler] Processed subsystems=%d"), Host->GetOrdered().Num());

    FPhysicsPipeline Physics;
    const FPhysicsStepStats PhysicsStats = Physics.Tick(*Kernel.Simulation, *Kernel.Config, FixedDt);

    ++Kernel.Simulation->Tick;

    const uint64 Hash = FWorldGraph::HashDeterministicSnapshot(*Kernel.Simulation);
    Kernel.NetworkingAuthority->SetFrameHash(Hash);
    Kernel.NetworkingAuthority->FinalizeFrame(Kernel.Simulation->Tick);

    Kernel.ReplayCertificationAuthority->RecordTickHash(Hash);
    UE_LOG(LogHelixReplay, VeryVerbose, TEXT("[Replay] Tick=%d | Hash=%llu"), Kernel.Simulation->Tick, Hash);

    const FSnapshotDiffResult Diff = FSnapshotDiff::Diff(Previous, *Kernel.Simulation);
    CollectInspectorData(PhysicsStats, Diff, Hash);

    if (Kernel.ProfilerAuthority->IsEnabled())
    {
        Kernel.ProfilerAuthority->EndFrame();
    }
}

FStressTestResult FRuntimeEntrypoint::RunSimulationStressTest(int32 EntityCount, int32 Steps, double Radius, double Amplitude)
{
    FStressTestResult Result;
    if (!bStarted || !Kernel.Simulation.IsValid())
    {
        return Result;
    }

    Kernel.Simulation->Bodies.Reset();
    Kernel.Simulation->Constraints.Reset();
    BeginReplayCertification(TEXT("StressHarness"));

    for (int32 I = 0; I < EntityCount; ++I)
    {
        const FHelixEntityId Id = FWorldGraph::CreateEntity(*Kernel.Simulation);
        FBodyComponent& Body = Kernel.Simulation->Bodies[Id];
        Body.Position = FVector3d(I * Radius, FMath::Sin(static_cast<double>(I)) * Amplitude, 0.0);
        Body.Velocity = FVector3d(10.0, 0.0, 0.0);
        FString ValidationReason;
        FContentValidator::ValidateAndSanitizeBody(Body, ValidationReason);
    }

    const double Start = FPlatformTime::Seconds();
    int32 MaxCollisions = 0;
    int32 MaxPairs = 0;

    for (int32 Step = 0; Step < Steps; ++Step)
    {
        TickFixedStep(Kernel.Config->FixedStep());
        MaxCollisions = FMath::Max(MaxCollisions, Inspector.Physics.Collisions);
        MaxPairs = FMath::Max(MaxPairs, Inspector.Physics.BroadphasePairs);
    }

    const double ElapsedMs = (FPlatformTime::Seconds() - Start) * 1000.0;
    Result.AverageStepMs = Steps > 0 ? (ElapsedMs / static_cast<double>(Steps)) : 0.0;
    Result.MaxCollisions = MaxCollisions;
    Result.MaxBroadphasePairs = MaxPairs;

    const FReplayCertificate Cert = Kernel.ReplayCertificationAuthority->EndReplayCertification();
    Result.ReplayDigest = Cert.Digest;

    return Result;
}

void FRuntimeEntrypoint::BeginReplayCertification(const FString& ScenarioId)
{
    Kernel.ReplayCertificationAuthority->BeginReplayCertification(ScenarioId);
}

FReplayCertificate FRuntimeEntrypoint::EndReplayCertification()
{
    return Kernel.ReplayCertificationAuthority->EndReplayCertification();
}

bool FRuntimeEntrypoint::CertifyReplayAgainstBaseline(const FReplayCertificate& Baseline, FString& OutReason) const
{
    return Kernel.ReplayCertificationAuthority->CertifyReplayAgainstBaseline(Baseline, OutReason);
}

bool FRuntimeEntrypoint::QueueClientInput(FName PlayerId, const FClientInputFrame& Input, FString& OutRejectReason)
{
    if (!bStarted || !Kernel.NetworkingAuthority.IsValid() || !Kernel.TimeAuthority.IsValid())
    {
        OutRejectReason = TEXT("runtime_not_ready");
        return false;
    }

    if (CVarHelixAuthoritativeNet.GetValueOnAnyThread() == 0 || !Kernel.Config->bAuthoritativeNetEnabled)
    {
        OutRejectReason = TEXT("authoritative_net_disabled");
        return false;
    }

    return Kernel.NetworkingAuthority->QueueClientInput(PlayerId, Input, static_cast<int32>(Kernel.TimeAuthority->GetTick()), OutRejectReason);
}

bool FRuntimeEntrypoint::SetSubsystemControlSource(FName SubsystemName, FName Source)
{
    return Host.IsValid() ? Host->SetSubsystemControlSource(SubsystemName, Source) : false;
}

void FRuntimeEntrypoint::CollectInspectorData(const FPhysicsStepStats& PhysicsStats, const FSnapshotDiffResult& Diff, uint64 Hash)
{
    if (CVarHelixDebugPanel.GetValueOnAnyThread() == 0)
    {
        return;
    }

    Inspector.Tick = Kernel.Simulation->Tick;
    Inspector.StateHash = Hash;
    Inspector.Diff = Diff;
    Inspector.Profile = Kernel.ProfilerAuthority->GetLastFrame();
    Inspector.Network = Kernel.NetworkingAuthority->GetLastFrameSummary();
    Inspector.RejectCount = Kernel.NetworkingAuthority->GetRejects().Num();
    Inspector.Physics = PhysicsStats;
}
