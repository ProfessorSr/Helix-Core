#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "ComponentSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Expansion Component Subsystem"))
class HELIX_API UComponentSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixExpansionComponentSubsystem"); }
};
