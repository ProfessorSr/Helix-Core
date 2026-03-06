#pragma once

#include "Subsystems/Expansion/StateSync/IStateSyncSubsystem.h"

class HELIX_API FUnrealStateSyncSubsystem final : public IStateSyncSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
