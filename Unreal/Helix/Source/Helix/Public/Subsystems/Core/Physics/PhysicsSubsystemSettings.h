#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "PhysicsSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Physics Subsystem"))
class HELIX_API UPhysicsSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCorePhysicsSubsystem"); }
};
