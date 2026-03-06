#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "AnimationSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Animation Subsystem"))
class HELIX_API UAnimationSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreAnimationSubsystem"); }
};
