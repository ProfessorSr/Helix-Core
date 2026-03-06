#pragma once

#include "Subsystems/Simulation/TimeScale/ITimeScaleSubsystem.h"

class HELIX_API FHelixTimeScaleSubsystem final : public ITimeScaleSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
