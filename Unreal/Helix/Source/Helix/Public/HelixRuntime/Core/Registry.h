#pragma once

#include "CoreMinimal.h"

struct FSubsystemManifestEntry;

class FSubsystemRegistry
{
public:
    bool BuildOrder(const TArray<FSubsystemManifestEntry>& InManifest, TArray<FSubsystemManifestEntry>& OutOrdered, FString& OutError) const;

private:
    bool VisitNode(
        const FName& Name,
        const TMap<FName, FSubsystemManifestEntry>& ByName,
        TSet<FName>& TempMarks,
        TSet<FName>& PermMarks,
        TArray<FSubsystemManifestEntry>& Ordered,
        FString& OutError) const;
};
