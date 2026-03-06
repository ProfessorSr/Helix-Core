#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "TimeSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Time Subsystem"))
class HELIX_API UTimeSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreTimeSubsystem"); }
};
