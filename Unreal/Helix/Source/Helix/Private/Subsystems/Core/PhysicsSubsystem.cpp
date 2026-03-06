#include "Subsystems/Core/PhysicsSubsystem.h"

#include "Components/BoxComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/PrimitiveComponent.h"
#include "Components/SphereComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "GameFramework/WorldSettings.h"
#include "GameFramework/Actor.h"
#include "PhysicsEngine/BodyInstance.h"
#include "HelixRuntime/Core/HelixConfig.h"
#include "HelixRuntime/Core/HelixLog.h"
#include "HelixRuntime/Runtime/RuntimeEntrypoint.h"
#include "HelixRuntime/Simulation/ContentValidator.h"
#include "HelixRuntime/Simulation/WorldGraph.h"
#include "UObject/UObjectIterator.h"
#include "HAL/IConsoleManager.h"

namespace
{
TAutoConsoleVariable<int32> CVarHelixGravityControlEnabled(
    TEXT("helix.GravityControlEnabled"),
    1,
    TEXT("0=Unreal controls gravity, 1=Helix config controls only world gravity while Unreal remains physics owner"));

UWorld* ResolveGameWorld()
{
    if (!GEngine)
    {
        return nullptr;
    }

    for (const FWorldContext& Context : GEngine->GetWorldContexts())
    {
        UWorld* World = Context.World();
        if (!World)
        {
            continue;
        }

        if (World->WorldType == EWorldType::PIE || World->WorldType == EWorldType::Game)
        {
            return World;
        }
    }

    return nullptr;
}

bool IsCollisionRelevant(UPrimitiveComponent* Comp)
{
    if (!IsValid(Comp) || !Comp->GetOwner())
    {
        return false;
    }
    if (!Comp->IsRegistered())
    {
        return false;
    }
    const ECollisionEnabled::Type CollisionEnabled = Comp->GetCollisionEnabled();
    if (CollisionEnabled == ECollisionEnabled::NoCollision)
    {
        return false;
    }
    if (CollisionEnabled == ECollisionEnabled::QueryOnly)
    {
        return false;
    }

    // Details panel collision responses are source-of-truth.
    bool bHasBlockingResponse = false;
    for (int32 ChannelIdx = 0; ChannelIdx < static_cast<int32>(ECC_MAX); ++ChannelIdx)
    {
        const ECollisionResponse Response = Comp->GetCollisionResponseToChannel(static_cast<ECollisionChannel>(ChannelIdx));
        if (Response == ECollisionResponse::ECR_Block)
        {
            bHasBlockingResponse = true;
            break;
        }
    }

    if (!bHasBlockingResponse)
    {
        return false;
    }

    if (Comp->GetOwner()->ActorHasTag(TEXT("NoHelixPhysics")))
    {
        return false;
    }

    return true;
}

bool IsConfiguredToSimulate(UPrimitiveComponent* Comp)
{
    if (!IsValid(Comp))
    {
        return false;
    }

    // Prefer Details-panel simulation state, with runtime state as backup.
    return Comp->BodyInstance.bSimulatePhysics || Comp->IsSimulatingPhysics();
}

bool ShouldTrackDynamic(UPrimitiveComponent* Comp)
{
    if (!IsValid(Comp))
    {
        return false;
    }

    // Details-panel simulation state is source-of-truth for dynamic bodies.
    return IsConfiguredToSimulate(Comp);
}

bool ShouldTrackStatic(UPrimitiveComponent* Comp)
{
    if (!IsValid(Comp))
    {
        return false;
    }

    if (IsConfiguredToSimulate(Comp))
    {
        return false;
    }

    // Treat only truly static, collidable, non-simulating components as static colliders.
    if (Comp->Mobility != EComponentMobility::Static)
    {
        return false;
    }
    return true;
}

struct FColliderSpec
{
    FVector3d Center = FVector3d::ZeroVector;
    EHelixColliderShape Shape = EHelixColliderShape::MeshBounds;
    FVector3d HalfExtents = FVector3d(50.0, 50.0, 50.0);
    double Radius = 50.0;
    double CapsuleHalfHeight = 50.0;
    const TCHAR* ShapeLabel = TEXT("MeshBounds");
};

FColliderSpec ComputeColliderSpec(UPrimitiveComponent* Comp)
{
    FColliderSpec Spec;
    Spec.Center = FVector3d(Comp->GetComponentLocation());

    if (const USphereComponent* Sphere = Cast<USphereComponent>(Comp))
    {
        Spec.Shape = EHelixColliderShape::Sphere;
        Spec.Radius = FMath::Max(static_cast<double>(Sphere->GetScaledSphereRadius()), 1.0);
        Spec.HalfExtents = FVector3d(Spec.Radius, Spec.Radius, Spec.Radius);
        Spec.CapsuleHalfHeight = Spec.Radius;
        Spec.ShapeLabel = TEXT("Sphere");
        return Spec;
    }

    if (const UBoxComponent* Box = Cast<UBoxComponent>(Comp))
    {
        const FVector Ext = Box->GetScaledBoxExtent();
        Spec.Shape = EHelixColliderShape::Box;
        Spec.HalfExtents = FVector3d(
            FMath::Max(FMath::Abs(static_cast<double>(Ext.X)), 0.01),
            FMath::Max(FMath::Abs(static_cast<double>(Ext.Y)), 0.01),
            FMath::Max(FMath::Abs(static_cast<double>(Ext.Z)), 0.01));
        Spec.Radius = Spec.HalfExtents.Size();
        Spec.CapsuleHalfHeight = FMath::Max3(Spec.HalfExtents.X, Spec.HalfExtents.Y, Spec.HalfExtents.Z);
        Spec.ShapeLabel = TEXT("Box");
        return Spec;
    }

    if (const UCapsuleComponent* Capsule = Cast<UCapsuleComponent>(Comp))
    {
        Spec.Shape = EHelixColliderShape::Capsule;
        Spec.Radius = FMath::Max(static_cast<double>(Capsule->GetScaledCapsuleRadius()), 1.0);
        Spec.CapsuleHalfHeight = FMath::Max(static_cast<double>(Capsule->GetScaledCapsuleHalfHeight()), Spec.Radius);
        Spec.HalfExtents = FVector3d(Spec.Radius, Spec.Radius, Spec.CapsuleHalfHeight);
        Spec.ShapeLabel = TEXT("Capsule");
        return Spec;
    }

    if (FBodyInstance* BodyInstance = Comp->GetBodyInstance())
    {
        if (BodyInstance->IsValidBodyInstance())
        {
            const FBox BodyBox = BodyInstance->GetBodyBounds();
            if (BodyBox.IsValid)
            {
                Spec.Center = FVector3d(BodyBox.GetCenter());
                const FVector BoundsExt = BodyBox.GetExtent();
                Spec.Shape = EHelixColliderShape::MeshBounds;
                Spec.HalfExtents = FVector3d(
                    FMath::Max(FMath::Abs(static_cast<double>(BoundsExt.X)), 0.01),
                    FMath::Max(FMath::Abs(static_cast<double>(BoundsExt.Y)), 0.01),
                    FMath::Max(FMath::Abs(static_cast<double>(BoundsExt.Z)), 0.01));
                Spec.Radius = Spec.HalfExtents.Size();
                Spec.CapsuleHalfHeight = FMath::Max3(Spec.HalfExtents.X, Spec.HalfExtents.Y, Spec.HalfExtents.Z);
                Spec.ShapeLabel = TEXT("BodyBounds");
                return Spec;
            }
        }
    }

    const FVector BoundsExt = Comp->Bounds.BoxExtent;
    Spec.Center = FVector3d(Comp->Bounds.Origin);
    Spec.Shape = EHelixColliderShape::MeshBounds;
    Spec.HalfExtents = FVector3d(
        FMath::Max(FMath::Abs(static_cast<double>(BoundsExt.X)), 0.01),
        FMath::Max(FMath::Abs(static_cast<double>(BoundsExt.Y)), 0.01),
        FMath::Max(FMath::Abs(static_cast<double>(BoundsExt.Z)), 0.01));
    Spec.Radius = Spec.HalfExtents.Size();
    Spec.CapsuleHalfHeight = FMath::Max3(Spec.HalfExtents.X, Spec.HalfExtents.Y, Spec.HalfExtents.Z);
    Spec.ShapeLabel = TEXT("MeshBounds");
    return Spec;
}

const TCHAR* ComputeReason(bool bDynamic, bool bBootstrapped)
{
    if (bDynamic)
    {
        return bBootstrapped ? TEXT("descendant_added") : TEXT("initial_scan");
    }

    return TEXT("Anchored");
}
}

void PhysicsSubsystem::Initialize()
{
}

void PhysicsSubsystem::Initialize(FHelixKernel& InKernel)
{
    bBootstrapped = false;
    bHelixBackendActive = false;
    bHelixGravityControlActive = false;
    bOriginalGlobalGravitySet = false;
    bOriginalGlobalGravityZ = 0.0f;
    LastAppliedGravityZ = TNumericLimits<double>::Lowest();
    DiscoveryAccumulator = 0.0;
    ManagedBodies.Reset();

    if (InKernel.Config.IsValid())
    {
        UE_LOG(
            LogHelixRuntime,
            Log,
            TEXT("[PhysicsSubsystem] Initialize | HelixEnabled=%s Gravity=%.3f"),
            InKernel.Config->bUseHelixPhysics ? TEXT("true") : TEXT("false"),
            static_cast<double>(InKernel.Config->PhysicsGravityZ)
        );
    }
}

void PhysicsSubsystem::Update(float FixedDeltaTime)
{
}

void PhysicsSubsystem::Update(float FixedDeltaTime, FHelixKernel& InKernel)
{
    if (!InKernel.Config.IsValid() || !InKernel.Simulation.IsValid())
    {
        return;
    }

    if (!InKernel.Config->bUseHelixPhysics)
    {
        ApplyHelixGravityControl(InKernel);

        if (bHelixBackendActive)
        {
            UE_LOG(LogHelixRuntime, Log, TEXT("[PhysicsSubsystem] Switching to Unreal backend"));
            RestoreUnrealPhysics();

            for (const FManagedBody& Managed : ManagedBodies)
            {
                InKernel.Simulation->Bodies.Remove(Managed.EntityId);
            }

            ManagedBodies.Reset();
            bBootstrapped = false;
            bHelixBackendActive = false;
        }
        return;
    }

    RestoreWorldGravity();

    if (!bHelixBackendActive)
    {
        UE_LOG(LogHelixRuntime, Log, TEXT("[PhysicsSubsystem] Switching to Helix backend"));
        bHelixBackendActive = true;
    }

    DiscoverAndRegisterBodies(InKernel);
    bBootstrapped = true;

    PushHelixStateToWorld(InKernel);
}

void PhysicsSubsystem::Shutdown()
{
    RestoreUnrealPhysics();
    RestoreWorldGravity();
}

void PhysicsSubsystem::Shutdown(FHelixKernel& InKernel)
{
    RestoreUnrealPhysics();
    RestoreWorldGravity();

    if (InKernel.Simulation.IsValid())
    {
        for (const FManagedBody& Managed : ManagedBodies)
        {
            InKernel.Simulation->Bodies.Remove(Managed.EntityId);
        }
    }

    ManagedBodies.Reset();
    bHelixBackendActive = false;
    bBootstrapped = false;
}

void PhysicsSubsystem::DiscoverAndRegisterBodies(FHelixKernel& InKernel)
{
    UWorld* World = ResolveGameWorld();
    if (!World || !InKernel.Simulation.IsValid())
    {
        return;
    }

    for (int32 Index = ManagedBodies.Num() - 1; Index >= 0; --Index)
    {
        FManagedBody Managed = ManagedBodies[Index];
        UPrimitiveComponent* Comp = Managed.Component.Get();

        if (!IsValid(Comp) || Comp->GetWorld() != World || !IsCollisionRelevant(Comp))
        {
            InKernel.Simulation->Bodies.Remove(Managed.EntityId);
            ManagedBodies.RemoveAtSwap(Index);
        }
    }

    for (TObjectIterator<UPrimitiveComponent> It; It; ++It)
    {
        UPrimitiveComponent* Comp = *It;
        if (!IsValid(Comp) || Comp->GetWorld() != World)
        {
            continue;
        }

        if (!IsCollisionRelevant(Comp))
        {
            continue;
        }

        const bool bDynamic = ShouldTrackDynamic(Comp);
        const bool bStatic = ShouldTrackStatic(Comp);
        if (!bDynamic && !bStatic)
        {
            continue;
        }

        const TCHAR* Reason = ComputeReason(bDynamic, bBootstrapped);
        TryRegisterBody(Comp, InKernel, !bBootstrapped, Reason);
    }
}

bool PhysicsSubsystem::TryRegisterBody(UPrimitiveComponent* Comp, FHelixKernel& InKernel, bool bForceResync, const TCHAR* Reason)
{
    const bool bRequestedDynamic = ShouldTrackDynamic(Comp);
    const bool bRequestedStatic = ShouldTrackStatic(Comp);

    FManagedBody* ExistingManaged = nullptr;
    for (FManagedBody& Managed : ManagedBodies)
    {
        if (Managed.Component.Get() == Comp)
        {
            ExistingManaged = &Managed;
            break;
        }
    }

    const bool bDynamic = bRequestedDynamic;
    const bool bStatic = !bDynamic && bRequestedStatic;
    if (!bDynamic && !bStatic)
    {
        return false;
    }

    if (ExistingManaged)
    {
        if (FBodyComponent* ExistingBody = InKernel.Simulation->Bodies.Find(ExistingManaged->EntityId))
        {
            const bool bWasDynamic = ExistingManaged->bIsDynamic;
            if (!bWasDynamic && bDynamic)
            {
                ExistingManaged->bOriginalSimulatePhysics = Comp->IsSimulatingPhysics();
                ExistingManaged->bOriginalEnableGravity = Comp->IsGravityEnabled();
                ExistingManaged->bIsDynamic = true;
            }
            else if (bWasDynamic && !bDynamic)
            {
                ExistingManaged->bIsDynamic = false;
            }

            const FColliderSpec ColliderSpec = ComputeColliderSpec(Comp);
            ExistingBody->Radius = ColliderSpec.Radius;
            ExistingBody->HalfExtents = ColliderSpec.HalfExtents;
            ExistingBody->CapsuleHalfHeight = ColliderSpec.CapsuleHalfHeight;
            ExistingBody->Shape = ColliderSpec.Shape;

            if (ExistingManaged->bIsDynamic)
            {
                const FVector3d ExternalCenter = ColliderSpec.Center;
                const double ExternalDeltaCm = (ExternalCenter - ExistingBody->Position).Size();
                if (bForceResync || !bWasDynamic || ExternalDeltaCm > 1.0)
                {
                    // Accept host-side displacement (e.g. character push) as authoritative input into Helix state.
                    ExistingBody->Position = ExternalCenter;
                }

                ExistingBody->Mass = FMath::Max(static_cast<double>(Comp->GetMass()), 0.001);
                ExistingBody->bEnableGravity = Comp->IsGravityEnabled();
                ExistingBody->bSleeping = false;
                ExistingBody->SleepFrames = 0;
                ExistingBody->Velocity = FVector3d(Comp->GetComponentVelocity());
            }
            else
            {
                ExistingBody->Position = ColliderSpec.Center;
                ExistingBody->Mass = 0.0;
                ExistingBody->bEnableGravity = false;
                ExistingBody->Velocity = FVector3d::ZeroVector;
                ExistingBody->bSleeping = true;
                ExistingBody->SleepFrames = 0;
            }
        }

        return true;
    }

    const FHelixEntityId EntityId = FWorldGraph::CreateEntity(*InKernel.Simulation);
    FBodyComponent& Body = InKernel.Simulation->Bodies[EntityId];
    const FColliderSpec ColliderSpec = ComputeColliderSpec(Comp);
    Body.Position = ColliderSpec.Center;
    Body.Radius = ColliderSpec.Radius;
    Body.HalfExtents = ColliderSpec.HalfExtents;
    Body.CapsuleHalfHeight = ColliderSpec.CapsuleHalfHeight;
    Body.Shape = ColliderSpec.Shape;

    if (bDynamic)
    {
        Body.Velocity = FVector3d(Comp->GetComponentVelocity());
        if (Comp->IsSimulatingPhysics())
        {
            Body.Mass = FMath::Max(static_cast<double>(Comp->GetMass()), 0.001);
        }
        else
        {
            Body.Mass = 1.0;
        }
        Body.bEnableGravity = Comp->IsGravityEnabled();
        Body.bSleeping = false;
        Body.SleepFrames = 0;
    }
    else
    {
        Body.Velocity = FVector3d::ZeroVector;
        Body.Mass = 0.0;
        Body.bEnableGravity = false;
        Body.bSleeping = true;
        Body.SleepFrames = 0;
    }

    FString ValidationReason;
    if (!FContentValidator::ValidateAndSanitizeBody(Body, ValidationReason))
    {
        UE_LOG(LogHelixValidation, Warning, TEXT("[PhysicsSubsystem] Rejected component %s | reason=%s"), *Comp->GetPathName(), *ValidationReason);
        InKernel.Simulation->Bodies.Remove(EntityId);
        return false;
    }

    FManagedBody Managed;
    Managed.Component = Comp;
    Managed.EntityId = EntityId;
    Managed.bOriginalSimulatePhysics = Comp->IsSimulatingPhysics();
    Managed.bOriginalEnableGravity = Comp->IsGravityEnabled();
    Managed.bIsDynamic = bDynamic;

    ManagedBodies.Add(Managed);

    const FString PartPath = Comp->GetPathName();
    const FString ClassName = Comp->GetClass() ? Comp->GetClass()->GetName() : TEXT("Unknown");
    UE_LOG(
        LogHelixRuntime,
        Log,
        TEXT("[WorldSubsystem] Registered EntityId=%lld Part=%s Class=%s Fidelity=n/a Reason=%s Shape=%s HitShape=%s Children=0 Decomp=false Baked=false JSON=false Fallback=false"),
        EntityId,
        *PartPath,
        *ClassName,
        Reason,
        ColliderSpec.ShapeLabel,
        ColliderSpec.ShapeLabel
    );

    return true;
}

void PhysicsSubsystem::PushHelixStateToWorld(FHelixKernel& InKernel)
{
    if (!InKernel.Simulation.IsValid())
    {
        return;
    }

    for (int32 I = ManagedBodies.Num() - 1; I >= 0; --I)
    {
        FManagedBody& Managed = ManagedBodies[I];
        UPrimitiveComponent* Comp = Managed.Component.Get();
        if (!IsValid(Comp))
        {
            InKernel.Simulation->Bodies.Remove(Managed.EntityId);
            ManagedBodies.RemoveAtSwap(I);
            continue;
        }

        FBodyComponent* Body = InKernel.Simulation->Bodies.Find(Managed.EntityId);
        if (!Body)
        {
            continue;
        }

        if (Managed.bIsDynamic)
        {
            const FColliderSpec ColliderSpec = ComputeColliderSpec(Comp);
            const FVector CenterOffset = FVector(ColliderSpec.Center) - Comp->GetComponentLocation();
            const FVector TargetComponentLocation = FVector(Body->Position) - CenterOffset;
            Comp->SetWorldLocation(TargetComponentLocation, false, nullptr, ETeleportType::TeleportPhysics);
        }
        else
        {
            const FColliderSpec ColliderSpec = ComputeColliderSpec(Comp);
            Body->Position = ColliderSpec.Center;
            Body->Radius = ColliderSpec.Radius;
            Body->HalfExtents = ColliderSpec.HalfExtents;
            Body->CapsuleHalfHeight = ColliderSpec.CapsuleHalfHeight;
            Body->Shape = ColliderSpec.Shape;
            Body->Velocity = FVector3d::ZeroVector;
            Body->Mass = 0.0;
            Body->bEnableGravity = false;
            Body->bSleeping = true;
            Body->SleepFrames = 0;
        }
    }
}

void PhysicsSubsystem::RestoreUnrealPhysics()
{
    // Intentionally no-op: runtime must not mutate Details-panel Simulate Physics or gravity flags.
}

void PhysicsSubsystem::ApplyHelixGravityControl(FHelixKernel& InKernel)
{
    if (CVarHelixGravityControlEnabled.GetValueOnAnyThread() == 0)
    {
        RestoreWorldGravity();
        return;
    }

    UWorld* World = ResolveGameWorld();
    if (!World || !InKernel.Config.IsValid())
    {
        return;
    }

    AWorldSettings* WorldSettings = World->GetWorldSettings();
    if (!WorldSettings)
    {
        return;
    }

    if (!bHelixGravityControlActive)
    {
        bOriginalGlobalGravitySet = WorldSettings->bGlobalGravitySet;
        bOriginalGlobalGravityZ = WorldSettings->GlobalGravityZ;
        bHelixGravityControlActive = true;
        UE_LOG(LogHelixRuntime, Log, TEXT("[PhysicsSubsystem] Helix gravity-only control enabled"));
    }

    const float TargetGravityZ = static_cast<float>(InKernel.Config->PhysicsGravityZ);
    if (!WorldSettings->bGlobalGravitySet || !FMath::IsNearlyEqual(WorldSettings->GlobalGravityZ, TargetGravityZ))
    {
        WorldSettings->bGlobalGravitySet = true;
        WorldSettings->GlobalGravityZ = TargetGravityZ;
    }

    if (!FMath::IsNearlyEqual(static_cast<float>(LastAppliedGravityZ), TargetGravityZ))
    {
        UE_LOG(LogHelixRuntime, Log, TEXT("[PhysicsSubsystem] Applied Helix gravity-only value: %.3f"), static_cast<double>(TargetGravityZ));
        LastAppliedGravityZ = TargetGravityZ;
    }
}

void PhysicsSubsystem::RestoreWorldGravity()
{
    if (!bHelixGravityControlActive)
    {
        return;
    }

    UWorld* World = ResolveGameWorld();
    if (World)
    {
        if (AWorldSettings* WorldSettings = World->GetWorldSettings())
        {
            WorldSettings->bGlobalGravitySet = bOriginalGlobalGravitySet;
            WorldSettings->GlobalGravityZ = bOriginalGlobalGravityZ;
        }
    }

    bHelixGravityControlActive = false;
    LastAppliedGravityZ = TNumericLimits<double>::Lowest();
    UE_LOG(LogHelixRuntime, Log, TEXT("[PhysicsSubsystem] Restored world gravity ownership to Unreal"));
}
