#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "EventSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Event Subsystem"))
class HELIX_API UEventSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreEventSubsystem"); }
};
