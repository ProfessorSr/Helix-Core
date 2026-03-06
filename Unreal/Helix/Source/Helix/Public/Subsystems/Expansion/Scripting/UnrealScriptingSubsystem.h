#pragma once

#include "Subsystems/Expansion/Scripting/IScriptingSubsystem.h"

class HELIX_API FUnrealScriptingSubsystem final : public IScriptingSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;
};
