#include "HelixRuntime/Authorities/ReplayCertificationAuthority.h"

void FReplayCertificationAuthority::BeginReplayCertification(const FString& ScenarioId)
{
    ActiveScenario = ScenarioId;
    WorkingHashes.Reset();
}

FReplayCertificate FReplayCertificationAuthority::EndReplayCertification()
{
    FReplayCertificate Certificate;
    Certificate.ScenarioId = ActiveScenario;
    Certificate.TickHashes = WorkingHashes;
    Certificate.Digest = FoldDigest(WorkingHashes);

    LastCertificate = Certificate;
    ActiveScenario.Empty();
    WorkingHashes.Reset();

    return Certificate;
}

bool FReplayCertificationAuthority::CertifyReplayAgainstBaseline(const FReplayCertificate& Baseline, FString& OutReason) const
{
    OutReason.Reset();

    if (LastCertificate.ScenarioId != Baseline.ScenarioId)
    {
        OutReason = TEXT("scenario_mismatch");
        return false;
    }

    if (LastCertificate.TickHashes.Num() != Baseline.TickHashes.Num())
    {
        OutReason = TEXT("tick_count_mismatch");
        return false;
    }

    if (LastCertificate.Digest != Baseline.Digest)
    {
        OutReason = TEXT("digest_mismatch");
        return false;
    }

    return true;
}

void FReplayCertificationAuthority::RecordTickHash(uint64 Hash)
{
    if (IsActive())
    {
        WorkingHashes.Add(Hash);
    }
}

uint64 FReplayCertificationAuthority::FoldDigest(const TArray<uint64>& Hashes)
{
    uint64 Digest = 1469598103934665603ull;
    for (uint64 H : Hashes)
    {
        Digest ^= H;
        Digest *= 1099511628211ull;
    }
    return Digest;
}
