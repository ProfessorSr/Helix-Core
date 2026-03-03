#pragma once

#include "CoreMinimal.h"

struct FSubsystemProfileFrame
{
    double TotalMs = 0.0;
    TMap<FName, double> SubsystemMs;
};

class FProfilerAuthority
{
public:
    void Initialize(bool bEnableProfiling) { bEnabled = bEnableProfiling; ResetFrame(); }
    void Shutdown() { bEnabled = false; ResetFrame(); }

    void BeginFrame();
    void AddSubsystemTime(FName Subsystem, double Ms);
    void EndFrame();

    bool IsEnabled() const { return bEnabled; }
    const FSubsystemProfileFrame& GetLastFrame() const { return LastFrame; }

private:
    bool bEnabled = true;
    FSubsystemProfileFrame CurrentFrame;
    FSubsystemProfileFrame LastFrame;

    void ResetFrame();
};
