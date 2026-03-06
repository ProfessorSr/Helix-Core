#pragma once

#include "Subsystems/Core/World/IWorldSubsystem.h"

class HELIX_API FUnrealWorldSubsystem final : public IWorldSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
