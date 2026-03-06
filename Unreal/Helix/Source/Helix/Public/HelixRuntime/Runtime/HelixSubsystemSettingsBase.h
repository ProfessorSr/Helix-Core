#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "HelixSubsystemSettingsBase.generated.h"

UENUM(BlueprintType)
enum class EHelixSubsystemControlOverride : uint8
{
    UseRouting = 0 UMETA(DisplayName = "Use Global Routing"),
    Unreal = 1 UMETA(DisplayName = "Unreal"),
    Host = Unreal UMETA(Hidden),
    Helix = 2 UMETA(DisplayName = "Helix")
};

UCLASS(Abstract, Config = Game, DefaultConfig)
class HELIX_API UHelixSubsystemSettingsBase : public UDeveloperSettings
{
    GENERATED_BODY()

public:
    virtual FName GetCategoryName() const override { return TEXT("Plugins"); }

    UPROPERTY(Config, EditAnywhere, Category = "General")
    bool bEnabled = true;

    UPROPERTY(Config, EditAnywhere, Category = "General")
    bool bDeterministic = true;

    UPROPERTY(Config, EditAnywhere, Category = "General")
    EHelixSubsystemControlOverride ControlSourceOverride = EHelixSubsystemControlOverride::UseRouting;

    UPROPERTY(Config, EditAnywhere, Category = "Debug")
    bool bVerboseRoutingLogs = false;

    TOptional<FName> ResolveControlSourceOverride() const
    {
        if (ControlSourceOverride == EHelixSubsystemControlOverride::UseRouting)
        {
            return TOptional<FName>();
        }

        return (ControlSourceOverride == EHelixSubsystemControlOverride::Helix)
            ? TOptional<FName>(FName(TEXT("Helix")))
            : TOptional<FName>(FName(TEXT("Unreal")));
    }
};
