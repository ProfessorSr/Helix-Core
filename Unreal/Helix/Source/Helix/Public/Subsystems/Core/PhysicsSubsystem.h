#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Simulation/WorldGraph.h"

class UPrimitiveComponent;
struct FHelixKernel;

struct FManagedBody
{
    TWeakObjectPtr<UPrimitiveComponent> Component;
    FHelixEntityId EntityId = 0;
    bool bOriginalSimulatePhysics = false;
    bool bOriginalEnableGravity = false;
    bool bIsDynamic = false;
};

class HELIX_API PhysicsSubsystem
{
public:
    void Initialize();
    void Initialize(FHelixKernel& InKernel);

    void Update(float FixedDeltaTime);
    void Update(float FixedDeltaTime, FHelixKernel& InKernel);

    void Shutdown();
    void Shutdown(FHelixKernel& InKernel);

private:
    void DiscoverAndRegisterBodies(FHelixKernel& InKernel);
    bool TryRegisterBody(UPrimitiveComponent* Comp, FHelixKernel& InKernel, bool bForceResync, const TCHAR* Reason);
    void PushHelixStateToWorld(FHelixKernel& InKernel);
    void RestoreUnrealPhysics();
    void ApplyHelixGravityControl(FHelixKernel& InKernel);
    void RestoreWorldGravity();

private:
    TArray<FManagedBody> ManagedBodies;
    bool bBootstrapped = false;
    bool bHelixBackendActive = false;
    bool bHelixGravityControlActive = false;
    bool bOriginalGlobalGravitySet = false;
    float bOriginalGlobalGravityZ = 0.0f;
    double LastAppliedGravityZ = TNumericLimits<double>::Lowest();
    double DiscoveryAccumulator = 0.0;
};
