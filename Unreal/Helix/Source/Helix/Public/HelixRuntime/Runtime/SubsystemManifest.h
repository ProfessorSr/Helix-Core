#pragma once

#include "CoreMinimal.h"

class ISubsystem;
class IReader;
class IWriter;

struct FSubsystemManifestEntry
{
    FName Name;
    FName Domain;
    int32 Phase = 0;
    TArray<FName> Dependencies;

    TFunction<TSharedPtr<ISubsystem>()> CreateSubsystem;
    TFunction<TSharedPtr<IReader>()> CreateReader;
    TFunction<TSharedPtr<IWriter>()> CreateWriter;
};
