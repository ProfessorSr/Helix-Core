#pragma once

#include "Subsystems/Core/Transform/ITransformSubsystem.h"

class HELIX_API FUnrealTransformSubsystem final : public ITransformSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
