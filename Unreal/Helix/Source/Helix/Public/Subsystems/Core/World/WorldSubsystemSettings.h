#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "WorldSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core World Subsystem"))
class HELIX_API UWorldSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreWorldSubsystem"); }
};
