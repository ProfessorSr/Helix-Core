#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "HelixSubsystemRoutingSettings.generated.h"

UENUM(BlueprintType)
enum class EHelixControlSourceSetting : uint8
{
    Unreal = 0 UMETA(DisplayName = "Unreal"),
    Host = Unreal UMETA(Hidden),
    Helix = 1 UMETA(DisplayName = "Helix")
};

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Helix Subsystem Routing"))
class HELIX_API UHelixSubsystemRoutingSettings : public UDeveloperSettings
{
    GENERATED_BODY()

public:
    virtual FName GetCategoryName() const override { return TEXT("Plugins"); }
    virtual FName GetSectionName() const override { return TEXT("HelixSubsystemRouting"); }

    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting AnimationSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting AudioSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting CameraSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting CharacterSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting EventSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting InputSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting NetworkingSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting PhysicsSubsystem = EHelixControlSourceSetting::Helix;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting TimeSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting TransformSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Core")
    EHelixControlSourceSetting WorldSubsystem = EHelixControlSourceSetting::Unreal;

    UPROPERTY(Config, EditAnywhere, Category = "Enterprise")
    EHelixControlSourceSetting AccountSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Enterprise")
    EHelixControlSourceSetting PersistenceSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Enterprise")
    EHelixControlSourceSetting PolicySubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Enterprise")
    EHelixControlSourceSetting SecuritySubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Enterprise")
    EHelixControlSourceSetting TelemetrySubsystem = EHelixControlSourceSetting::Unreal;

    UPROPERTY(Config, EditAnywhere, Category = "Expansion")
    EHelixControlSourceSetting AssetSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Expansion")
    EHelixControlSourceSetting ComponentSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Expansion")
    EHelixControlSourceSetting ReplicationSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Expansion")
    EHelixControlSourceSetting ScriptingSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Expansion")
    EHelixControlSourceSetting StateSyncSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Expansion")
    EHelixControlSourceSetting UISubsystem = EHelixControlSourceSetting::Unreal;

    UPROPERTY(Config, EditAnywhere, Category = "Simulation")
    EHelixControlSourceSetting SimulationControlSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Simulation")
    EHelixControlSourceSetting StepDebuggerSubsystem = EHelixControlSourceSetting::Unreal;
    UPROPERTY(Config, EditAnywhere, Category = "Simulation")
    EHelixControlSourceSetting TimeScaleSubsystem = EHelixControlSourceSetting::Unreal;

    static FName ToControlSourceName(EHelixControlSourceSetting Source)
    {
        return (Source == EHelixControlSourceSetting::Helix) ? FName(TEXT("Helix")) : FName(TEXT("Unreal"));
    }

    void BuildSubsystemSourceMap(TArray<TPair<FName, FName>>& OutMap) const;
};
