#pragma once

#include "Subsystems/Enterprise/Policy/IPolicySubsystem.h"

class HELIX_API FUnrealPolicySubsystem final : public IPolicySubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
