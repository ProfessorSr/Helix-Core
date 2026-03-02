#pragma once

#include <vector>
#include <functional>

class FHelixCore
{
public:

    enum class EPhase
    {
        Uninitialized,
        Booting,
        Validating,
        InitializingSubsystems,
        Locked,
        Running,
        ShuttingDown,
        Terminated
    };

    FHelixCore();

    // Lifecycle
    void Boot();
    void Update(float DeltaTime);
    void Shutdown();

    // Subsystem registration
    void RegisterSubsystem(std::function<void(float)> System);

    // State query
    EPhase GetPhase() const { return CurrentPhase; }

private:

    // Internal helpers
    void Transition(EPhase NewPhase);
    void RequirePhase(EPhase Required) const;

private:

    EPhase CurrentPhase;

    std::vector<std::function<void(float)>> Subsystems;

    float Accumulator;
    float FixedStep;

    bool bRegistryLocked;
};
