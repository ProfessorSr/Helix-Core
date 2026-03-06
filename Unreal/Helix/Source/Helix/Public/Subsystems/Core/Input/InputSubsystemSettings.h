#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "InputSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Input Subsystem"))
class HELIX_API UInputSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreInputSubsystem"); }
};
