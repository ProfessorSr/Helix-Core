#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "StepDebuggerSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Simulation StepDebugger Subsystem"))
class HELIX_API UStepDebuggerSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixSimulationStepDebuggerSubsystem"); }
};
