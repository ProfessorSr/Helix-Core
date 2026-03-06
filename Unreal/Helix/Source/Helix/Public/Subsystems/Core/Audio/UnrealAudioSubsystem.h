#pragma once

#include "Subsystems/Core/Audio/IAudioSubsystem.h"

class HELIX_API FUnrealAudioSubsystem final : public IAudioSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
