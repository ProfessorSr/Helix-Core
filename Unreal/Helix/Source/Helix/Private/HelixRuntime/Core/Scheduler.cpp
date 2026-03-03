#include "HelixRuntime/Core/Scheduler.h"

#include "HelixRuntime/Runtime/RuntimeEntrypoint.h"
#include "HelixRuntime/Core/HelixConfig.h"
#include "HelixRuntime/Core/HelixLog.h"

FDeterministicFixedStepScheduler::FDeterministicFixedStepScheduler(FHelixKernel& InKernel, TFunction<void(double)> InOnFixedTick)
    : Kernel(InKernel)
    , OnFixedTick(MoveTemp(InOnFixedTick))
{
    if (Kernel.Config.IsValid())
    {
        UE_LOG(LogHelixScheduler, Log, TEXT("[Scheduler] Initialized | FixedStep=%.6f | MaxTicksPerFrame=%d"), Kernel.Config->FixedStep(), Kernel.Config->MaxStepsPerFrame);
    }
}

void FDeterministicFixedStepScheduler::Reset()
{
    TickIndex = 0;
    Accumulator = 0.0;
}

void FDeterministicFixedStepScheduler::Advance(double DeltaSeconds)
{
    if (!Kernel.Config.IsValid())
    {
        return;
    }

    const double FixedDt = Kernel.Config->FixedStep();
    Accumulator += DeltaSeconds;

    int32 Steps = 0;
    while (Accumulator >= FixedDt && Steps < Kernel.Config->MaxStepsPerFrame)
    {
        ++Steps;
        ++TickIndex;
        UE_LOG(LogHelixScheduler, VeryVerbose, TEXT("[Scheduler] Tick=%llu Dt=%.6f"), TickIndex, FixedDt);
        if (OnFixedTick)
        {
            OnFixedTick(FixedDt);
        }

        Accumulator -= FixedDt;
    }

    if (Steps == Kernel.Config->MaxStepsPerFrame && Accumulator >= FixedDt)
    {
        const int32 RequestedTicks = static_cast<int32>(Accumulator / FixedDt);
        UE_LOG(LogHelixScheduler, Warning, TEXT("[Scheduler] Clamp applied | RequestedTicks=%d | Executed=%d"), RequestedTicks, Steps);
        Accumulator = 0.0;
    }
}
