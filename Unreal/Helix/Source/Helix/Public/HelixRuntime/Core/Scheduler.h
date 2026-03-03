#pragma once

#include "CoreMinimal.h"

struct FHelixKernel;

class FDeterministicFixedStepScheduler
{
public:
    FDeterministicFixedStepScheduler(FHelixKernel& InKernel, TFunction<void(double)> InOnFixedTick);

    void Reset();
    void Advance(double DeltaSeconds);

    uint64 GetTickIndex() const { return TickIndex; }
    double GetAccumulator() const { return Accumulator; }

private:
    FHelixKernel& Kernel;
    TFunction<void(double)> OnFixedTick;
    uint64 TickIndex = 0;
    double Accumulator = 0.0;
};
