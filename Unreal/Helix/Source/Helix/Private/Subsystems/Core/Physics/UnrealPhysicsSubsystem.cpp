#include "Subsystems/Core/Physics/UnrealPhysicsSubsystem.h"
#include "HelixRuntime/Runtime/RuntimeEntrypoint.h"

void FUnrealPhysicsSubsystem::Initialize(FHelixKernel& Kernel)
{
    BoundKernel = &Kernel;
    Implementation.Initialize(Kernel);
}

void FUnrealPhysicsSubsystem::Update(double FixedDt)
{
    if (!BoundKernel)
    {
        return;
    }

    bool bRestoreConfig = false;
    bool bPreviousUseHelix = false;
    if (BoundKernel->Config.IsValid())
    {
        bRestoreConfig = true;
        bPreviousUseHelix = BoundKernel->Config->bUseHelixPhysics;
        BoundKernel->Config->bUseHelixPhysics = false;
    }

    Implementation.Update(static_cast<float>(FixedDt), *BoundKernel);

    if (bRestoreConfig && BoundKernel->Config.IsValid())
    {
        BoundKernel->Config->bUseHelixPhysics = bPreviousUseHelix;
    }
}

void FUnrealPhysicsSubsystem::Shutdown()
{
    if (BoundKernel)
    {
        Implementation.Shutdown(*BoundKernel);
    }
    else
    {
        Implementation.Shutdown();
    }
    BoundKernel = nullptr;
}
