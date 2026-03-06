#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "StateSyncSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Expansion StateSync Subsystem"))
class HELIX_API UStateSyncSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixExpansionStateSyncSubsystem"); }
};
