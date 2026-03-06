#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "CharacterSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Core Character Subsystem"))
class HELIX_API UCharacterSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixCoreCharacterSubsystem"); }
};
