#pragma once

#include "HelixRuntime/Runtime/HelixSubsystemSettingsBase.h"
#include "ScriptingSubsystemSettings.generated.h"

UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Expansion Scripting Subsystem"))
class HELIX_API UScriptingSubsystemSettings : public UHelixSubsystemSettingsBase
{
    GENERATED_BODY()

public:
    virtual FName GetSectionName() const override { return TEXT("HelixExpansionScriptingSubsystem"); }
};
