#pragma once

#include "Subsystems/Core/Physics/IPhysicsSubsystem.h"
#include "Subsystems/Core/PhysicsSubsystem.h"

struct FHelixKernel;

class HELIX_API FHelixPhysicsSubsystem final : public IPhysicsSubsystem
{
public:
    virtual void Initialize(FHelixKernel& Kernel) override;
    virtual void Update(double FixedDt) override;
    virtual void Shutdown() override;

private:
    FHelixKernel* BoundKernel = nullptr;
    PhysicsSubsystem Implementation;
};
