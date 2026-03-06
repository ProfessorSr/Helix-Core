#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "AccountSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Enterprise Account Subsystem"))
class HELIX_API UAccountSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixEnterpriseAccountSubsystem"); }
};
