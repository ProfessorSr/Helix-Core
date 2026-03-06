#pragma once

#include "Subsystems/Simulation/StepDebugger/IStepDebuggerSubsystem.h"

class HELIX_API FHelixStepDebuggerSubsystem final : public IStepDebuggerSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
