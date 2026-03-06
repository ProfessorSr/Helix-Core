#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "PersistenceSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Enterprise Persistence Subsystem"))
class HELIX_API UPersistenceSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixEnterprisePersistenceSubsystem"); }
};
