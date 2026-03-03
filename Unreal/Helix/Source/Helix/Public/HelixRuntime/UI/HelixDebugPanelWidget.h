#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "HelixRuntime/Simulation/DevTools.h"
#include "HelixDebugPanelWidget.generated.h"

UCLASS(BlueprintType, Blueprintable)
class HELIX_API UHelixDebugPanelWidget : public UUserWidget
{
    GENERATED_BODY()

public:
    void SetInspectorPayload(const FDebugInspectorData& InPayload) { Payload = InPayload; }

    const FDebugInspectorData& GetInspectorPayload() const { return Payload; }

private:
    FDebugInspectorData Payload;
};
