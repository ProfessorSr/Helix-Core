#include "HelixRuntime/Authorities/ProfilerAuthority.h"

void FProfilerAuthority::BeginFrame()
{
    if (!bEnabled)
    {
        return;
    }

    ResetFrame();
}

void FProfilerAuthority::AddSubsystemTime(FName Subsystem, double Ms)
{
    if (!bEnabled)
    {
        return;
    }

    CurrentFrame.TotalMs += Ms;
    CurrentFrame.SubsystemMs.FindOrAdd(Subsystem) += Ms;
}

void FProfilerAuthority::EndFrame()
{
    if (!bEnabled)
    {
        return;
    }

    LastFrame = CurrentFrame;
}

void FProfilerAuthority::ResetFrame()
{
    CurrentFrame.TotalMs = 0.0;
    CurrentFrame.SubsystemMs.Reset();
}
