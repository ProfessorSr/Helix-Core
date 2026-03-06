#pragma once

#include "Subsystems/Expansion/Asset/IAssetSubsystem.h"

class HELIX_API FUnrealAssetSubsystem final : public IAssetSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
