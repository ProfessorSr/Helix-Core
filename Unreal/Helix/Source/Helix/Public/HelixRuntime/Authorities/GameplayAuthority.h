#pragma once

#include "CoreMinimal.h"

class FNetworkingAuthority;

class FGameplayAuthority
{
public:
    void Initialize(TSharedPtr<FNetworkingAuthority> InNetworking) { NetworkingAuthority = InNetworking; }
    void Shutdown() { ProcessedInputsThisTick = 0; }
    void ProcessTick();

    int32 GetProcessedInputsThisTick() const { return ProcessedInputsThisTick; }

private:
    TSharedPtr<FNetworkingAuthority> NetworkingAuthority;
    int32 ProcessedInputsThisTick = 0;
};
