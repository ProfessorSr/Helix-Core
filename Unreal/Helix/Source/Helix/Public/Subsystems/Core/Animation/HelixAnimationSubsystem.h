#pragma once

#include "Subsystems/Core/Animation/IAnimationSubsystem.h"

class HELIX_API FHelixAnimationSubsystem final : public IAnimationSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
