#pragma once

#include "Subsystems/Enterprise/Telemetry/ITelemetrySubsystem.h"

class HELIX_API FUnrealTelemetrySubsystem final : public ITelemetrySubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
