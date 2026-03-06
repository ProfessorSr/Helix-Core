#pragma once

#include "Subsystems/Core/Event/IEventSubsystem.h"

class HELIX_API FHelixEventSubsystem final : public IEventSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
