#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "ReplicationSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Expansion Replication Subsystem"))
class HELIX_API UReplicationSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixExpansionReplicationSubsystem"); }
};
