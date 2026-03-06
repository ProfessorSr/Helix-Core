#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "UISubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Expansion UI Subsystem"))
class HELIX_API UUISubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixExpansionUISubsystem"); }
};
