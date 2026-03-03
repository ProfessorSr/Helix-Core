#pragma once

#include <vector>
#include <functional>
#include <cstdint>
#include <random>
using uint64 = uint64_t;

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

    static constexpr float DefaultTickRate = 60.0f;
    explicit FHelixCore(float InTickRate = DefaultTickRate);

    // Lifecycle
    void Boot();
    void Update(float DeltaTime);
    void Shutdown();

    // Subsystem registration
    void RegisterSubsystem(std::function<void(float)> System);

    // State query
    EPhase GetPhase() const { return CurrentPhase; }
    float GetFixedStep() const;
    float GetTickRate() const;
    uint64 GetTickIndex() const;
    float GetElapsedSeconds() const;
    void SetTickRate(float NewTickRate);

    // Time scaling
    float GetTimeScale() const;
    void SetTimeScale(float NewTimeScale);

    // Deterministic RNG
    uint64 GetSeed() const;
    void SetSeed(uint64 NewSeed);
    uint64 NextRandom();

private:

    // Internal helpers
    void Transition(EPhase NewPhase);
    void RequirePhase(EPhase Required) const;

private:

    EPhase CurrentPhase;

    std::vector<std::function<void(float)>> Subsystems;

    float Accumulator;

    float TickRate;
    float FixedStep;
    uint64 TickIndex;
    float ElapsedSeconds;

    float TimeScale;

    uint64 RandomSeed;
    std::mt19937_64 RNG;

    bool bRegistryLocked;
};
