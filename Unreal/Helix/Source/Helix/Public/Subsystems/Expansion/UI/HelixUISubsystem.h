#pragma once

#include "Subsystems/Expansion/UI/IUISubsystem.h"

class HELIX_API FHelixUISubsystem final : public IUISubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
