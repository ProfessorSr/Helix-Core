#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "PolicySubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Enterprise Policy Subsystem"))
class HELIX_API UPolicySubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixEnterprisePolicySubsystem"); }
};
