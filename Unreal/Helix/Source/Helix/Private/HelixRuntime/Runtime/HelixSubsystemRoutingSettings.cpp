#include "HelixRuntime/Runtime/HelixSubsystemRoutingSettings.h"

void UHelixSubsystemRoutingSettings::BuildSubsystemSourceMap(TArray<TPair<FName, FName>>& OutMap) const
{
    OutMap.Reset();

    auto Add = [&OutMap](const TCHAR* SubsystemName, EHelixControlSourceSetting Source)
    {
        OutMap.Emplace(FName(SubsystemName), ToControlSourceName(Source));
    };

    Add(TEXT("AnimationSubsystem"), AnimationSubsystem);
    Add(TEXT("AudioSubsystem"), AudioSubsystem);
    Add(TEXT("CameraSubsystem"), CameraSubsystem);
    Add(TEXT("CharacterSubsystem"), CharacterSubsystem);
    Add(TEXT("EventSubsystem"), EventSubsystem);
    Add(TEXT("InputSubsystem"), InputSubsystem);
    Add(TEXT("NetworkingSubsystem"), NetworkingSubsystem);
    Add(TEXT("PhysicsSubsystem"), PhysicsSubsystem);
    Add(TEXT("TimeSubsystem"), TimeSubsystem);
    Add(TEXT("TransformSubsystem"), TransformSubsystem);
    Add(TEXT("WorldSubsystem"), WorldSubsystem);

    Add(TEXT("AccountSubsystem"), AccountSubsystem);
    Add(TEXT("PersistenceSubsystem"), PersistenceSubsystem);
    Add(TEXT("PolicySubsystem"), PolicySubsystem);
    Add(TEXT("SecuritySubsystem"), SecuritySubsystem);
    Add(TEXT("TelemetrySubsystem"), TelemetrySubsystem);

    Add(TEXT("AssetSubsystem"), AssetSubsystem);
    Add(TEXT("ComponentSubsystem"), ComponentSubsystem);
    Add(TEXT("ReplicationSubsystem"), ReplicationSubsystem);
    Add(TEXT("ScriptingSubsystem"), ScriptingSubsystem);
    Add(TEXT("StateSyncSubsystem"), StateSyncSubsystem);
    Add(TEXT("UISubsystem"), UISubsystem);

    Add(TEXT("SimulationControlSubsystem"), SimulationControlSubsystem);
    Add(TEXT("StepDebuggerSubsystem"), StepDebuggerSubsystem);
    Add(TEXT("TimeScaleSubsystem"), TimeScaleSubsystem);
}
