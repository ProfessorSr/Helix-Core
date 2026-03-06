#include "Misc/AutomationTest.h"

#include "HelixRuntime/Core/HelixConfig.h"
#include "HelixRuntime/Runtime/RuntimeEntrypoint.h"
#include "HelixRuntime/Runtime/SubsystemManifest.h"
#include "HelixRuntime/Simulation/PhysicsPipeline.h"
#include "HelixRuntime/Simulation/WorldGraph.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FHelixPhysicsGravityStepTest,
    "Helix.Physics.GravityStep",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FHelixPhysicsGravityStepTest::RunTest(const FString& Parameters)
{
    FHelixConfig Config;
    Config.bUseHelixPhysics = true;
    Config.PhysicsMaxSubsteps = 1;
    Config.PhysicsCollisionIterations = 0;
    Config.PhysicsConstraintIterations = 0;
    Config.PhysicsGravityZ = -980.0;

    FSimulationState State;
    const FHelixEntityId Id = FWorldGraph::CreateEntity(State);
    FBodyComponent& Body = State.Bodies[Id];
    Body.Position = FVector3d(0.0, 0.0, 1000.0);
    Body.Velocity = FVector3d::ZeroVector;
    Body.Radius = 50.0;

    FPhysicsPipeline Pipeline;
    const double Dt = 1.0 / 60.0;
    Pipeline.Tick(State, Config, Dt);

    TestTrue(TEXT("Velocity should move downward after gravity"), State.Bodies[Id].Velocity.Z < 0.0);
    TestTrue(TEXT("Position Z should decrease after gravity step"), State.Bodies[Id].Position.Z < 1000.0);

    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FHelixPhysicsCollisionClampTest,
    "Helix.Physics.CollisionClamp",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FHelixPhysicsCollisionClampTest::RunTest(const FString& Parameters)
{
    FHelixConfig Config;
    Config.bUseHelixPhysics = true;
    Config.PhysicsMaxSubsteps = 1;
    Config.PhysicsCollisionIterations = 2;
    Config.PhysicsConstraintIterations = 0;
    Config.PhysicsGravityZ = 0.0;

    FSimulationState State;
    const FHelixEntityId A = FWorldGraph::CreateEntity(State);
    const FHelixEntityId B = FWorldGraph::CreateEntity(State);

    FBodyComponent& BodyA = State.Bodies[A];
    FBodyComponent& BodyB = State.Bodies[B];

    BodyA.Position = FVector3d(0.0, 0.0, 0.0);
    BodyA.Radius = 100.0;
    BodyA.Mass = 1.0;

    BodyB.Position = FVector3d(0.0, 0.0, 10.0);
    BodyB.Radius = 100.0;
    BodyB.Mass = 1.0;

    FPhysicsPipeline Pipeline;
    const FPhysicsStepStats Stats = Pipeline.Tick(State, Config, 1.0 / 60.0);

    TestTrue(TEXT("Should detect at least one collision"), Stats.Collisions > 0);

    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FHelixPhysicsStaticImmovableTest,
    "Helix.Physics.StaticImmovable",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FHelixPhysicsStaticImmovableTest::RunTest(const FString& Parameters)
{
    FHelixConfig Config;
    Config.bUseHelixPhysics = true;
    Config.PhysicsMaxSubsteps = 1;
    Config.PhysicsCollisionIterations = 2;
    Config.PhysicsConstraintIterations = 0;
    Config.PhysicsGravityZ = 0.0;

    FSimulationState State;
    const FHelixEntityId StaticId = FWorldGraph::CreateEntity(State);
    const FHelixEntityId DynamicId = FWorldGraph::CreateEntity(State);

    FBodyComponent& StaticBody = State.Bodies[StaticId];
    FBodyComponent& DynamicBody = State.Bodies[DynamicId];

    StaticBody.Position = FVector3d(0.0, 0.0, 0.0);
    StaticBody.Radius = 100.0;
    StaticBody.Mass = 0.0;
    StaticBody.bSleeping = true;

    DynamicBody.Position = FVector3d(0.0, 0.0, 10.0);
    DynamicBody.Radius = 100.0;
    DynamicBody.Mass = 1.0;

    const FVector3d BeforeStatic = StaticBody.Position;

    FPhysicsPipeline Pipeline;
    const FPhysicsStepStats Stats = Pipeline.Tick(State, Config, 1.0 / 60.0);

    TestTrue(TEXT("Should detect at least one collision"), Stats.Collisions > 0);
    TestTrue(TEXT("Static body should not move"), State.Bodies[StaticId].Position.Equals(BeforeStatic, KINDA_SMALL_NUMBER));

    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FHelixRuntimePhysicsToggleTest,
    "Helix.Physics.RuntimeToggle",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FHelixRuntimePhysicsToggleTest::RunTest(const FString& Parameters)
{
    FHelixConfig Config;
    Config.TickRate = 60.0;
    Config.bUseHelixPhysics = false;
    Config.PhysicsGravityZ = -980.0;
    Config.PhysicsMaxSubsteps = 1;
    Config.PhysicsCollisionIterations = 0;
    Config.PhysicsConstraintIterations = 0;

    FRuntimeEntrypoint Runtime;
    FString Error;
    TArray<FSubsystemManifestEntry> EmptyManifest;

    const bool bStarted = Runtime.Start(Config, EmptyManifest, Error);
    TestTrue(TEXT("Runtime should start"), bStarted);
    if (!bStarted)
    {
        AddError(FString::Printf(TEXT("Runtime failed to start: %s"), *Error));
        return false;
    }

    FSimulationState& Sim = *Runtime.GetKernel().Simulation;
    const FHelixEntityId Id = FWorldGraph::CreateEntity(Sim);
    FBodyComponent& Body = Sim.Bodies[Id];
    Body.Position = FVector3d(0.0, 0.0, 1000.0);
    Body.Velocity = FVector3d::ZeroVector;
    Body.Radius = 50.0;
    Body.Mass = 1.0;

    Runtime.TickFixedStep(1.0 / 60.0);
    TestTrue(TEXT("Body should not move while Helix physics is disabled"), FMath::IsNearlyEqual(Sim.Bodies[Id].Position.Z, 1000.0, KINDA_SMALL_NUMBER));

    Runtime.GetKernel().Config->bUseHelixPhysics = true;
    Runtime.TickFixedStep(1.0 / 60.0);
    TestTrue(TEXT("Body should move once Helix physics is enabled"), Sim.Bodies[Id].Position.Z < 1000.0);

    Runtime.Stop();
    return true;
}

#endif
