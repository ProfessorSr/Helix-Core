#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "CameraSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Camera Subsystem"))
class HELIX_API UCameraSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreCameraSubsystem"); }
};
