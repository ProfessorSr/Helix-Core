#pragma once

#include "Subsystems/Core/Camera/ICameraSubsystem.h"

class HELIX_API FHelixCameraSubsystem final : public ICameraSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
