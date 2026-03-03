#include "HelixCore.h"

FHelixCore::FHelixCore(float InTickRate)
    : CurrentPhase(EPhase::Uninitialized)
    , Accumulator(0.0f)
    , TickRate(InTickRate)
    , FixedStep(1.0f / TickRate)
    , TickIndex(0)
    , ElapsedSeconds(0.0f)
    , TimeScale(1.0f)
    , RandomSeed(0)
    , RNG(0)
    , bRegistryLocked(false)
{
}

void FHelixCore::Boot()
{
    RequirePhase(EPhase::Uninitialized);
    Transition(EPhase::Booting);

    Transition(EPhase::Validating);

    Transition(EPhase::InitializingSubsystems);

    bRegistryLocked = true;
    Transition(EPhase::Locked);
    Transition(EPhase::Running);
}

void FHelixCore::Update(float DeltaTime)
{
    RequirePhase(EPhase::Running);

    // Apply time scaling
    const float ScaledDelta = DeltaTime * TimeScale;
    Accumulator += ScaledDelta;

    const int32 MaxStepsPerFrame = 5;
    int32 Steps = 0;

    while (Accumulator >= FixedStep && Steps < MaxStepsPerFrame)
    {
        // Advance authoritative time
        TickIndex++;
        ElapsedSeconds += FixedStep;

        for (auto& System : Subsystems)
        {
            System(FixedStep);
        }

        Accumulator -= FixedStep;
        Steps++;
    }

    // Prevent spiral-of-death by dropping excess accumulated time
    if (Steps == MaxStepsPerFrame && Accumulator >= FixedStep)
    {
        Accumulator = 0.0f;
    }
}

void FHelixCore::Shutdown()
{
    if (CurrentPhase == EPhase::Terminated)
        return;

    RequirePhase(EPhase::Running);

    Transition(EPhase::ShuttingDown);

    Subsystems.clear();
    bRegistryLocked = false;

    Transition(EPhase::Terminated);
}

void FHelixCore::RegisterSubsystem(std::function<void(float)> System)
{
    if (bRegistryLocked)
    {
        throw std::runtime_error("Registry locked. Cannot register subsystem.");
    }

    Subsystems.push_back(System);
}

void FHelixCore::Transition(EPhase NewPhase)
{
    CurrentPhase = NewPhase;
}

void FHelixCore::RequirePhase(EPhase Required) const
{
    if (CurrentPhase != Required)
    {
        throw std::runtime_error("Illegal phase transition.");
    }
}

float FHelixCore::GetFixedStep() const
{
    return FixedStep;
}

float FHelixCore::GetTickRate() const
{
    return TickRate;
}

uint64 FHelixCore::GetTickIndex() const
{
    return TickIndex;
}

float FHelixCore::GetElapsedSeconds() const
{
    return ElapsedSeconds;
}

void FHelixCore::SetTickRate(float NewTickRate)
{
    if (bRegistryLocked)
    {
        throw std::runtime_error("Cannot change TickRate after boot.");
    }

    TickRate = NewTickRate;
    FixedStep = 1.0f / TickRate;
}

float FHelixCore::GetTimeScale() const
{
    return TimeScale;
}

void FHelixCore::SetTimeScale(float NewTimeScale)
{
    TimeScale = NewTimeScale;
}

uint64 FHelixCore::GetSeed() const
{
    return RandomSeed;
}

void FHelixCore::SetSeed(uint64 NewSeed)
{
    RandomSeed = NewSeed;
    RNG.seed(RandomSeed);
}

uint64 FHelixCore::NextRandom()
{
    return RNG();
}
