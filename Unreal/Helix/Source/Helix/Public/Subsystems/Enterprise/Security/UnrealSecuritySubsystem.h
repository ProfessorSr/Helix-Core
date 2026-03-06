#pragma once

#include "Subsystems/Enterprise/Security/ISecuritySubsystem.h"

class HELIX_API FUnrealSecuritySubsystem final : public ISecuritySubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
