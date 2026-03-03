#pragma once

#include "CoreMinimal.h"

struct FHelixKernel;

class IReader
{
public:
    virtual ~IReader() = default;
    virtual void Initialize(FHelixKernel& Kernel) = 0;
    virtual void Tick(double Dt) = 0;
    virtual void Shutdown() = 0;
};
