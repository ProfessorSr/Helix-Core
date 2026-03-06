#pragma once

#include "Subsystems/Core/Input/IInputSubsystem.h"

class HELIX_API FHelixInputSubsystem final : public IInputSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
