#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "SecuritySubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Enterprise Security Subsystem"))
class HELIX_API USecuritySubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixEnterpriseSecuritySubsystem"); }
};
