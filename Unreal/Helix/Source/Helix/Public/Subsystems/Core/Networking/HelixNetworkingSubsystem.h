#pragma once

#include "Subsystems/Core/Networking/INetworkingSubsystem.h"

class HELIX_API FHelixNetworkingSubsystem final : public INetworkingSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
