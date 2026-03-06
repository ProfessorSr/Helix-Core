#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "SimulationControlSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Simulation SimulationControl Subsystem"))
class HELIX_API USimulationControlSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixSimulationSimulationControlSubsystem"); }
};
