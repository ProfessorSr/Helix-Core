#pragma once

#include "CoreMinimal.h"

struct FHelixKernel;

class HELIX_API IScriptingSubsystem
{
public:
    virtual ~IScriptingSubsystem();

    virtual void Initialize(FHelixKernel& Kernel) = 0;
    virtual void Update(double FixedDt) = 0;
    virtual void Shutdown() = 0;
};
