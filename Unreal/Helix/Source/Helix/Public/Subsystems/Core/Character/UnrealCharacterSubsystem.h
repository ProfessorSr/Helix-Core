#pragma once

#include "Subsystems/Core/Character/ICharacterSubsystem.h"

class HELIX_API FUnrealCharacterSubsystem final : public ICharacterSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
