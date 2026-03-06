#include "HelixRuntime/Runtime/RuntimeRouter.h"

#include "HelixRuntime/Core/Registry.h"
#include "HelixRuntime/Core/HelixLog.h"
#include "HelixRuntime/Runtime/ISubsystem.h"
#include "HelixRuntime/Runtime/IReader.h"
#include "HelixRuntime/Runtime/IWriter.h"
#include "HelixRuntime/Runtime/RuntimeEntrypoint.h"

namespace
{
FName NormalizeControlSourceName(FName Source)
{
    return (Source == FName(TEXT("Host"))) ? FName(TEXT("Unreal")) : Source;
}
}

bool FRuntimeRouter::Start(FHelixKernel& Kernel, const TArray<FSubsystemManifestEntry>& Manifest, FString& OutError)
{
    OutError.Reset();
    Ordered.Reset();
    UE_LOG(LogHelixRouter, Log, TEXT("[RuntimeRouter] Loading SubsystemManifest"));

    FSubsystemRegistry Registry;
    TArray<FSubsystemManifestEntry> OrderedManifest;
    if (!Registry.BuildOrder(Manifest, OrderedManifest, OutError))
    {
        return false;
    }

    for (const FSubsystemManifestEntry& Entry : OrderedManifest)
    {
        UE_LOG(LogHelixRouter, Log, TEXT("[RuntimeRouter] Loaded Subsystem: %s | Domain=%s | Phase=%d"), *Entry.Name.ToString(), *Entry.Domain.ToString(), Entry.Phase);
        FRuntimeSubsystemInstance Instance;
        Instance.Manifest = Entry;
        Instance.Subsystem = Entry.CreateSubsystem ? Entry.CreateSubsystem() : nullptr;
        Instance.Reader = Entry.CreateReader ? Entry.CreateReader() : nullptr;
        Instance.Writer = Entry.CreateWriter ? Entry.CreateWriter() : nullptr;

        if (!Instance.Subsystem.IsValid())
        {
            OutError = FString::Printf(TEXT("Subsystem '%s' factory returned null"), *Entry.Name.ToString());
            Stop(Kernel);
            return false;
        }

        if (Instance.Reader.IsValid())
        {
            Instance.Reader->Initialize(Kernel);
            const FString ReaderName = FString::Printf(TEXT("%sReader"), *Entry.Name.ToString());
            UE_LOG(LogHelixRouter, Log, TEXT("[RuntimeRouter] Initialized Reader: %s"), *ReaderName);
        }
        if (Instance.Writer.IsValid())
        {
            Instance.Writer->Initialize(Kernel);
            const FString WriterName = FString::Printf(TEXT("%sWriter"), *Entry.Name.ToString());
            UE_LOG(LogHelixRouter, Log, TEXT("[RuntimeRouter] Initialized Writer: %s"), *WriterName);
        }

        Instance.Subsystem->Init(Kernel, Instance.Reader, Instance.Writer);

        Instance.Subsystem->SetControlSource(FName(TEXT("Unreal")));

        Instance.Subsystem->Start();
        UE_LOG(LogHelixRouter, Log, TEXT("[RuntimeRouter] Started Subsystem: %s | Source=%s"), *Entry.Name.ToString(), *Instance.Subsystem->GetControlSource().ToString());

        Ordered.Add(Instance);
    }

    return true;
}

void FRuntimeRouter::Stop(FHelixKernel& Kernel)
{
    UE_LOG(LogHelixRouter, Log, TEXT("[RuntimeRouter] Stopping subsystems (reverse order)"));
    for (int32 I = Ordered.Num() - 1; I >= 0; --I)
    {
        FRuntimeSubsystemInstance& Instance = Ordered[I];
        if (Instance.Subsystem.IsValid())
        {
            Instance.Subsystem->Stop();
            UE_LOG(LogHelixRouter, Log, TEXT("[RuntimeRouter] Stopped Subsystem: %s"), *Instance.Manifest.Name.ToString());
        }
        if (Instance.Writer.IsValid())
        {
            Instance.Writer->Shutdown();
        }
        if (Instance.Reader.IsValid())
        {
            Instance.Reader->Shutdown();
        }
    }

    Ordered.Reset();
}

bool FRuntimeRouter::SetSubsystemControlSource(FName SubsystemName, FName Source)
{
    Source = NormalizeControlSourceName(Source);
    for (FRuntimeSubsystemInstance& Instance : Ordered)
    {
        if (Instance.Manifest.Name == SubsystemName && Instance.Subsystem.IsValid())
        {
            const FName Previous = Instance.Subsystem->GetControlSource();
            if (Previous == Source)
            {
                return true;
            }
            Instance.Subsystem->SetControlSource(Source);
            UE_LOG(LogHelixRuntime, Log, TEXT("[Runtime] ControlSource changed | Subsystem=%s | From=%s | To=%s"), *SubsystemName.ToString(), *Previous.ToString(), *Source.ToString());
            UE_LOG(LogHelixRuntime, Log, TEXT("[Runtime] ActiveSource | %s=%s"), *SubsystemName.ToString(), *Instance.Subsystem->GetControlSource().ToString());
            return true;
        }
    }

    return false;
}
