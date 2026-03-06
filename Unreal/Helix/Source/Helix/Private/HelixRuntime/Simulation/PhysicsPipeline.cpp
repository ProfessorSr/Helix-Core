#include "HelixRuntime/Simulation/PhysicsPipeline.h"

#include "HelixRuntime/Core/HelixConfig.h"

FPhysicsStepStats FPhysicsPipeline::Tick(FSimulationState& State, const FHelixConfig& Config, double Dt) const
{
    FPhysicsStepStats Stats;

    const int32 Substeps = FMath::Clamp(Config.PhysicsMaxSubsteps, 1, 16);
    const double SubstepDt = Dt / static_cast<double>(Substeps);

    for (int32 Step = 0; Step < Substeps; ++Step)
    {
        for (TPair<FHelixEntityId, FBodyComponent>& Entry : State.Bodies)
        {
            FBodyComponent& Body = Entry.Value;
            if (Body.bSleeping)
            {
                continue;
            }

            if (Body.bEnableGravity)
            {
                Body.Velocity.Z += Config.PhysicsGravityZ * SubstepDt;
            }
            Body.Position += Body.Velocity * SubstepDt;
        }

        const TArray<FBroadphasePair> Pairs = Broadphase.Run(State.Bodies);
        Stats.BroadphasePairs = FMath::Max(Stats.BroadphasePairs, Pairs.Num());

        const FCollisionStats CollisionStats = Collision.Run(
            State,
            Pairs,
            Config.PhysicsCollisionIterations,
            Config.PhysicsBaumgarte,
            Config.PhysicsPenetrationSlop,
            Config.PhysicsMaxCorrection,
            Config.PhysicsMaxSpeed);

        Stats.Collisions = FMath::Max(Stats.Collisions, CollisionStats.CollisionCount);

        Constraints.Solve(State, Config.PhysicsConstraintIterations);

        for (TPair<FHelixEntityId, FBodyComponent>& Entry : State.Bodies)
        {
            FBodyComponent& Body = Entry.Value;
            if (Body.Velocity.Size() <= Config.PhysicsSleepVelocity)
            {
                Body.SleepFrames++;
                if (Body.SleepFrames >= Config.PhysicsSleepFrames)
                {
                    Body.bSleeping = true;
                    Body.Velocity = FVector3d::ZeroVector;
                }
            }
            else
            {
                Body.SleepFrames = 0;
                Body.bSleeping = false;
            }
        }

        ++Stats.Substeps;
    }

    return Stats;
}
