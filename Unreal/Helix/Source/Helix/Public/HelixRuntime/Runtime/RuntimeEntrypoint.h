#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Core/HelixConfig.h"
#include "HelixRuntime/Authorities/ReplayCertificationAuthority.h"
#include "HelixRuntime/Simulation/DevTools.h"

class FTimeAuthority;
class FEventAuthority;
class FGameplayAuthority;
class FDomainSchemaAuthority;
class FNetworkingAuthority;
class FReplayCertificationAuthority;
class FProfilerAuthority;
class FDeterministicFixedStepScheduler;
class FRuntimeRouter;
struct FSimulationState;

struct FHelixKernel
{
    TSharedPtr<FHelixConfig> Config;
    TSharedPtr<FTimeAuthority> TimeAuthority;
    TSharedPtr<FEventAuthority> EventAuthority;
    TSharedPtr<FGameplayAuthority> GameplayAuthority;
    TSharedPtr<FDomainSchemaAuthority> DomainSchemaAuthority;
    TSharedPtr<FNetworkingAuthority> NetworkingAuthority;
    TSharedPtr<FReplayCertificationAuthority> ReplayCertificationAuthority;
    TSharedPtr<FProfilerAuthority> ProfilerAuthority;
    TSharedPtr<FSimulationState> Simulation;
};

struct FStressTestResult
{
    double AverageStepMs = 0.0;
    int32 MaxCollisions = 0;
    int32 MaxBroadphasePairs = 0;
    uint64 ReplayDigest = 0;
};

class FRuntimeEntrypoint
{
public:
    bool Start(const FHelixConfig& InitialConfig, const TArray<struct FSubsystemManifestEntry>& Manifest, FString& OutError);
    void Stop();

    void TickFixedStep(double Dt);

    const FDebugInspectorData& GetInspectorData() const { return Inspector; }

    FStressTestResult RunSimulationStressTest(int32 EntityCount, int32 Steps, double Radius, double Amplitude);
    void BeginReplayCertification(const FString& ScenarioId);
    FReplayCertificate EndReplayCertification();
    bool CertifyReplayAgainstBaseline(const FReplayCertificate& Baseline, FString& OutReason) const;
    bool QueueClientInput(FName PlayerId, const FClientInputFrame& Input, FString& OutRejectReason);

    bool SetSubsystemControlSource(FName SubsystemName, FName Source);

    FHelixKernel& GetKernel() { return Kernel; }
    const FHelixKernel& GetKernel() const { return Kernel; }

private:
    void TickOneStep(double FixedDt);
    void CollectInspectorData(const FPhysicsStepStats& PhysicsStats, const FSnapshotDiffResult& Diff, uint64 Hash);

    FHelixKernel Kernel;
    TSharedPtr<FDeterministicFixedStepScheduler> Scheduler;
    TSharedPtr<FRuntimeRouter> Router;

    bool bStarted = false;
    FDebugInspectorData Inspector;
};
