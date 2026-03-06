#pragma once

#include "Subsystems/Core/Time/ITimeSubsystem.h"

class HELIX_API FUnrealTimeSubsystem final : public ITimeSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
