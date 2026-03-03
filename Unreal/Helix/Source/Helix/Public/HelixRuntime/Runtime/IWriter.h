#pragma once

#include "CoreMinimal.h"

struct FHelixKernel;

class IWriter
{
public:
    virtual ~IWriter() = default;
    virtual void Initialize(FHelixKernel& Kernel) = 0;
    virtual void Enqueue(FName Command, const FString& Payload) = 0;
    virtual void Tick(double Dt) = 0;
    virtual void Shutdown() = 0;
};
