#pragma once

#include "Subsystems/Expansion/Replication/IReplicationSubsystem.h"

class HELIX_API FHelixReplicationSubsystem final : public IReplicationSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
