#include "HelixHost.h"
#include "Engine/Engine.h"

// Sets default values
AHelixHost::AHelixHost()
{
    PrimaryActorTick.bCanEverTick = true;
}

// Called when the game starts or when spawned
void AHelixHost::BeginPlay()
{
    Super::BeginPlay();

    Core.Boot();
}

// Called every frame
void AHelixHost::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);

    Core.Update(DeltaTime);

    static float Elapsed = 0.0f;
    static int32 FixedStepCount = 0;

    Elapsed += DeltaTime;

    // Count fixed steps (assuming 60Hz target)
    const float FixedStep = 1.0f / 60.0f;
    static float Accumulator = 0.0f;
    Accumulator += DeltaTime;

    while (Accumulator >= FixedStep)
    {
        FixedStepCount++;
        Accumulator -= FixedStep;
    }

    if (Elapsed >= 1.0f)
    {
        FString PhaseString;

        switch (Core.GetPhase())
        {
            case FHelixCore::EPhase::Uninitialized: PhaseString = "Uninitialized"; break;
            case FHelixCore::EPhase::Booting: PhaseString = "Booting"; break;
            case FHelixCore::EPhase::Validating: PhaseString = "Validating"; break;
            case FHelixCore::EPhase::InitializingSubsystems: PhaseString = "InitializingSubsystems"; break;
            case FHelixCore::EPhase::Locked: PhaseString = "Locked"; break;
            case FHelixCore::EPhase::Running: PhaseString = "Running"; break;
            case FHelixCore::EPhase::ShuttingDown: PhaseString = "ShuttingDown"; break;
            case FHelixCore::EPhase::Terminated: PhaseString = "Terminated"; break;
            default: PhaseString = "Unknown"; break;
        }

        const float Hz = FixedStepCount / Elapsed;

        UE_LOG(LogTemp, Warning, TEXT("[HelixHost] Phase=%s | FixedStepsLastSecond=%d | Hz=%.2f"),
            *PhaseString,
            FixedStepCount,
            Hz);

        FixedStepCount = 0;
        Elapsed = 0.0f;
    }
}

void AHelixHost::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    Core.Shutdown();

    Super::EndPlay(EndPlayReason);
}
