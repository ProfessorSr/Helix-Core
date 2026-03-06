#include "Subsystems/Core/Physics/HelixPhysicsSubsystem.h"
#include "HelixRuntime/Runtime/RuntimeEntrypoint.h"

void FHelixPhysicsSubsystem::Initialize(FHelixKernel& Kernel)
{
    BoundKernel = &Kernel;
    Implementation.Initialize(Kernel);
}

void FHelixPhysicsSubsystem::Update(double FixedDt)
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
        BoundKernel->Config->bUseHelixPhysics = true;
    }

    Implementation.Update(static_cast<float>(FixedDt), *BoundKernel);

    if (bRestoreConfig && BoundKernel->Config.IsValid())
    {
        BoundKernel->Config->bUseHelixPhysics = bPreviousUseHelix;
    }
}

void FHelixPhysicsSubsystem::Shutdown()
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
