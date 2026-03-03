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

    UE_LOG(LogTemp, Warning, TEXT("[Helix] Host Capabilities Registered:"));
    UE_LOG(LogTemp, Warning, TEXT("    Time.FixedStep = true"));
    UE_LOG(LogTemp, Warning, TEXT("    Lifecycle.Boot = true"));
    UE_LOG(LogTemp, Warning, TEXT("    Lifecycle.LockRegistry = true"));
    UE_LOG(LogTemp, Warning, TEXT("    Scheduler.Update = true"));

    UE_LOG(LogTemp, Warning, TEXT("[Helix] Required Capability Registered: Time.FixedStep"));
    UE_LOG(LogTemp, Warning, TEXT("[Helix] Required Capability Registered: Lifecycle.Boot"));
    UE_LOG(LogTemp, Warning, TEXT("[Helix] Required Capability Registered: Lifecycle.LockRegistry"));
    UE_LOG(LogTemp, Warning, TEXT("[Helix] Required Capability Registered: Scheduler.Update"));

    UE_LOG(LogTemp, Warning, TEXT("[Helix] Capability validation successful."));

    // -------------------------------
    // Subsystem Wiring
    // -------------------------------

    Time.Initialize();
    Input.Initialize();
    Event.Initialize();
    World.Initialize();

    Physics.Initialize();
    Vehicle.Initialize();
    Character.Initialize();
    Camera.Initialize();
    Animation.Initialize();
    AI.Initialize();

    Climate.Initialize();
    Audio.Initialize();
    Lighting.Initialize();

    Networking.Initialize();
    Replication.Initialize();
    SaveLoad.Initialize();
    Economy.Initialize();

    Core.RegisterSubsystem([this](float Step)
    {
        Time.Update(Step);
        Input.Update(Step);
        Event.Update(Step);
        World.Update(Step);

        Physics.Update(Step);
        Vehicle.Update(Step);
        Character.Update(Step);
        Camera.Update(Step);
        Animation.Update(Step);
        AI.Update(Step);

        Climate.Update(Step);
        Audio.Update(Step);
        Lighting.Update(Step);

        Networking.Update(Step);
        Replication.Update(Step);
        SaveLoad.Update(Step);
        Economy.Update(Step);
    });

    Core.Boot();

    // ----------------------------------------------------------------
    // Subsystem Wiring Example
    // ----------------------------------------------------------------
    // Example pattern when adding a subsystem:
    //
    // MySubsystem.Initialize();
    //
    // Core.RegisterSubsystem([this](float Step)
    // {
    //     MySubsystem.Update(Step);
    // });
    //
    // Then call MySubsystem.Shutdown() inside EndPlay().
    // ----------------------------------------------------------------
}

// Called every frame
void AHelixHost::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);

    Core.Update(DeltaTime);

    static float Elapsed = 0.0f;
    static uint64 LastTickIndex = 0;

    Elapsed += DeltaTime;

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

        const uint64 CurrentTickIndex = Core.GetTickIndex();
        const int32 FixedStepCount = static_cast<int32>(CurrentTickIndex - LastTickIndex);
        LastTickIndex = CurrentTickIndex;

        const float Hz = FixedStepCount / Elapsed;

        UE_LOG(LogTemp, Warning, TEXT("[HelixHost] Phase=%s | FixedStepsLastSecond=%d | Hz=%.2f"),
            *PhaseString,
            FixedStepCount,
            Hz);

        Elapsed = 0.0f;
    }
}

void AHelixHost::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    // ----------------------------------------------------------------
    // Subsystem Shutdown Example
    // ----------------------------------------------------------------
    // MySubsystem.Shutdown();
    // ----------------------------------------------------------------
    Time.Shutdown();
    Input.Shutdown();
    Event.Shutdown();
    World.Shutdown();

    Physics.Shutdown();
    Vehicle.Shutdown();
    Character.Shutdown();
    Camera.Shutdown();
    Animation.Shutdown();
    AI.Shutdown();

    Climate.Shutdown();
    Audio.Shutdown();
    Lighting.Shutdown();

    Networking.Shutdown();
    Replication.Shutdown();
    SaveLoad.Shutdown();
    Economy.Shutdown();
    Core.Shutdown();

    Super::EndPlay(EndPlayReason);
}
