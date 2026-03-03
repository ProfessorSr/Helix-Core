#pragma once

#include "CoreMinimal.h"

class FTimeAuthority
{
public:
    void Initialize(double InFixedStep) { FixedStep = InFixedStep; }
    void Shutdown() { Tick = 0; Seconds = 0.0; }
    void Advance()
    {
        ++Tick;
        Seconds += FixedStep;
    }

    uint64 GetTick() const { return Tick; }
    double GetSeconds() const { return Seconds; }

private:
    uint64 Tick = 0;
    double Seconds = 0.0;
    double FixedStep = 1.0 / 60.0;
};
