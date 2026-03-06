#include "HelixRuntime/Core/Registry.h"

#include "HelixRuntime/Core/HelixLog.h"
#include "HelixRuntime/Runtime/SubsystemManifest.h"

bool FSubsystemRegistry::BuildOrder(
    const TArray<FSubsystemManifestEntry>& InManifest,
    TArray<FSubsystemManifestEntry>& OutOrdered,
    FString& OutError) const
{
    OutOrdered.Reset();
    OutError.Reset();

    TMap<FName, FSubsystemManifestEntry> ByName;
    for (const FSubsystemManifestEntry& Entry : InManifest)
    {
        if (Entry.Name.IsNone())
        {
            OutError = TEXT("Manifest entry has empty name");
            return false;
        }

        if (ByName.Contains(Entry.Name))
        {
            OutError = FString::Printf(TEXT("Duplicate subsystem '%s'"), *Entry.Name.ToString());
            return false;
        }

        ByName.Add(Entry.Name, Entry);
    }

    TSet<FName> TempMarks;
    TSet<FName> PermMarks;

    TArray<FName> Names;
    ByName.GetKeys(Names);
    Names.Sort(FNameLexicalLess());

    for (const FName& Name : Names)
    {
        if (!PermMarks.Contains(Name) && !VisitNode(Name, ByName, TempMarks, PermMarks, OutOrdered, OutError))
        {
            return false;
        }
    }

    OutOrdered.Sort([](const FSubsystemManifestEntry& A, const FSubsystemManifestEntry& B)
    {
        if (A.Phase == B.Phase)
        {
            return A.Name.LexicalLess(B.Name);
        }
        return A.Phase < B.Phase;
    });

    return true;
}

bool FSubsystemRegistry::VisitNode(
    const FName& Name,
    const TMap<FName, FSubsystemManifestEntry>& ByName,
    TSet<FName>& TempMarks,
    TSet<FName>& PermMarks,
    TArray<FSubsystemManifestEntry>& Ordered,
    FString& OutError) const
{
    if (PermMarks.Contains(Name))
    {
        return true;
    }

    if (TempMarks.Contains(Name))
    {
        OutError = FString::Printf(TEXT("Dependency cycle detected at '%s'"), *Name.ToString());
        UE_LOG(LogHelixRuntime, Error, TEXT("[RuntimeRouter] Dependency cycle detected: %s"), *OutError);
        return false;
    }

    const FSubsystemManifestEntry* Entry = ByName.Find(Name);
    if (!Entry)
    {
        OutError = FString::Printf(TEXT("Missing dependency '%s'"), *Name.ToString());
        return false;
    }

    TempMarks.Add(Name);

    TArray<FName> Dependencies = Entry->Dependencies;
    Dependencies.Sort(FNameLexicalLess());

    for (const FName& Dependency : Dependencies)
    {
        if (!ByName.Contains(Dependency))
        {
            OutError = FString::Printf(TEXT("Subsystem '%s' depends on missing '%s'"), *Name.ToString(), *Dependency.ToString());
            UE_LOG(LogHelixRuntime, Error, TEXT("[RuntimeRouter] %s"), *OutError);
            return false;
        }

        if (!VisitNode(Dependency, ByName, TempMarks, PermMarks, Ordered, OutError))
        {
            return false;
        }
    }

    TempMarks.Remove(Name);
    PermMarks.Add(Name);
    Ordered.Add(*Entry);

    return true;
}
