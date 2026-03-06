#pragma once

#include "Subsystems/Expansion/Component/IComponentSubsystem.h"

class HELIX_API FHelixComponentSubsystem final : public IComponentSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
