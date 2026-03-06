#pragma once

#include "CoreMinimal.h"

struct FHelixKernel;

class HELIX_API IPolicySubsystem
{
public:
    virtual ~IPolicySubsystem();

    virtual void Initialize(FHelixKernel& Kernel) = 0;
    virtual void Update(double FixedDt) = 0;
    virtual void Shutdown() = 0;
};
