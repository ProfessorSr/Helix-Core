#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "NetworkingSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Networking Subsystem"))
class HELIX_API UNetworkingSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreNetworkingSubsystem"); }
};
