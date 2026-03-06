#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "TransformSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Transform Subsystem"))
class HELIX_API UTransformSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreTransformSubsystem"); }
};
