#include "HelixCore.h"

FHelixCore::FHelixCore()
    : CurrentPhase(EPhase::Uninitialized)
    , Accumulator(0.0f)
    , FixedStep(1.0f / 60.0f)
    , bRegistryLocked(false)
{
}

void FHelixCore::Boot()
{
    RequirePhase(EPhase::Uninitialized);
    Transition(EPhase::Booting);

    Transition(EPhase::Validating);
    // Dependency validation logic goes here

    Transition(EPhase::InitializingSubsystems);
    // Subsystem initialization hooks (if added later)

    bRegistryLocked = true;
    Transition(EPhase::Locked);
    Transition(EPhase::Running);
}

void FHelixCore::Update(float DeltaTime)
{
    RequirePhase(EPhase::Running);

    Accumulator += DeltaTime;

    while (Accumulator >= FixedStep)
    {
        for (auto& System : Subsystems)
        {
            System(FixedStep);
        }

        Accumulator -= FixedStep;
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
