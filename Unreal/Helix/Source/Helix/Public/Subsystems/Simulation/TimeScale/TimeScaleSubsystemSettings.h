#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "TimeScaleSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Simulation TimeScale Subsystem"))
class HELIX_API UTimeScaleSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixSimulationTimeScaleSubsystem"); }
};
