#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "AudioSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Audio Subsystem"))
class HELIX_API UAudioSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreAudioSubsystem"); }
};
