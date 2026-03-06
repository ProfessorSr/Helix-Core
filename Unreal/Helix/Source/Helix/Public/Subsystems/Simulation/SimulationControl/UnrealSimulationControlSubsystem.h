#pragma once

#include "Subsystems/Simulation/SimulationControl/ISimulationControlSubsystem.h"

class HELIX_API FUnrealSimulationControlSubsystem final : public ISimulationControlSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
