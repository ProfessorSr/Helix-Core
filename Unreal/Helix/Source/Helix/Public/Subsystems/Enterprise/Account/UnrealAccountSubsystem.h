#pragma once

#include "Subsystems/Enterprise/Account/IAccountSubsystem.h"

class HELIX_API FUnrealAccountSubsystem final : public IAccountSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
