#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Runtime/SubsystemManifest.h"

struct FHelixKernel;
class FSubsystemRegistry;

struct FRuntimeSubsystemInstance
{
    FSubsystemManifestEntry Manifest;
    TSharedPtr<class ISubsystem> Subsystem;
    TSharedPtr<class IReader> Reader;
    TSharedPtr<class IWriter> Writer;
};

class FRuntimeRouter
{
public:
    bool Start(FHelixKernel& Kernel, const TArray<FSubsystemManifestEntry>& Manifest, FString& OutError);
    void Stop(FHelixKernel& Kernel);

    const TArray<FRuntimeSubsystemInstance>& GetOrdered() const { return Ordered; }

    bool SetSubsystemControlSource(FName SubsystemName, FName Source);

private:
    TArray<FRuntimeSubsystemInstance> Ordered;
};
