#include "HelixRuntime/Authorities/GameplayAuthority.h"

#include "HelixRuntime/Authorities/NetworkingAuthority.h"

void FGameplayAuthority::ProcessTick()
{
    ProcessedInputsThisTick = 0;

    if (!NetworkingAuthority.IsValid())
    {
        return;
    }

    TArray<TPair<FName, FClientInputFrame>> Inputs;
    const int32 Tick = NetworkingAuthority->GetLastFrameSummary().Tick + 1;
    ProcessedInputsThisTick = NetworkingAuthority->ConsumeAcceptedInputsForTick(Tick, Inputs);
}
