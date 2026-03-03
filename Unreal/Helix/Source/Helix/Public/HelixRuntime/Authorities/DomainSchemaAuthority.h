#pragma once

#include "CoreMinimal.h"

class FDomainSchemaAuthority
{
public:
    void Initialize(const TArray<FName>& InDomains)
    {
        Domains = InDomains;
        Domains.Sort(FNameLexicalLess());
    }

    void Shutdown() { Domains.Reset(); }

    bool HasDomain(FName Domain) const { return Domains.Contains(Domain); }

private:
    TArray<FName> Domains;
};
