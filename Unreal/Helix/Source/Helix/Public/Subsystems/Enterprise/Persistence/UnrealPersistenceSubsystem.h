#pragma once

#include "Subsystems/Enterprise/Persistence/IPersistenceSubsystem.h"

class HELIX_API FUnrealPersistenceSubsystem final : public IPersistenceSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
