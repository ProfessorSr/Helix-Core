#pragma once

#include "CoreMinimal.h"

struct FReplayCertificate
{
    FString ScenarioId;
    TArray<uint64> TickHashes;
    uint64 Digest = 0;
};

class FReplayCertificationAuthority
{
public:
    void Initialize() {}
    void Shutdown() { ActiveScenario.Empty(); WorkingHashes.Reset(); }

    void BeginReplayCertification(const FString& ScenarioId);
    FReplayCertificate EndReplayCertification();
    bool CertifyReplayAgainstBaseline(const FReplayCertificate& Baseline, FString& OutReason) const;

    void RecordTickHash(uint64 Hash);
    bool IsActive() const { return !ActiveScenario.IsEmpty(); }

private:
    FString ActiveScenario;
    TArray<uint64> WorkingHashes;
    FReplayCertificate LastCertificate;

    static uint64 FoldDigest(const TArray<uint64>& Hashes);
};
