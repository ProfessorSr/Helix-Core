#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "AssetSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Expansion Asset Subsystem"))
class HELIX_API UAssetSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixExpansionAssetSubsystem"); }
};
