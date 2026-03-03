#pragma once

#include "CoreMinimal.h"

struct FHelixConfig;

struct FClientInputFrame
{
    int32 Tick = 0;
    int32 Sequence = 0;
    FName Command;
};

struct FInputRejectRecord
{
    FName PlayerId;
    int32 Tick = 0;
    int32 Sequence = 0;
    FString Reason;
};

struct FPlayerInputState
{
    int32 LastSequence = -1;
    int32 Accepted = 0;
    int32 Rejected = 0;
};

struct FAuthoritativeFrameSummary
{
    int32 Tick = 0;
    uint64 Hash = 0;
    int32 InputCount = 0;
    int32 Rejects = 0;
};

class FNetworkingAuthority
{
public:
    void Initialize(const FHelixConfig& Config);
    void Shutdown();

    bool QueueClientInput(FName PlayerId, const FClientInputFrame& Input, int32 ServerTick, FString& OutRejectReason);
    int32 ConsumeAcceptedInputsForTick(int32 Tick, TArray<TPair<FName, FClientInputFrame>>& OutInputs);

    void SetFrameHash(uint64 Hash) { CurrentFrame.Hash = Hash; }
    void FinalizeFrame(int32 Tick);

    const TArray<FInputRejectRecord>& GetRejects() const { return RejectRing; }
    const TMap<FName, FPlayerInputState>& GetPlayerState() const { return PlayerState; }
    const FAuthoritativeFrameSummary& GetLastFrameSummary() const { return LastFrame; }

private:
    struct FQueuedInput
    {
        FName Player;
        FClientInputFrame Frame;
    };

    int32 MaxFutureTicks = 4;
    int32 MaxPastTicks = 12;
    int32 MaxInputsPerPlayerPerTick = 8;
    int32 MaxInputsPerTick = 2048;
    int32 RejectBufferSize = 512;

    TMap<int32, TArray<FQueuedInput>> AcceptedByTick;
    TMap<TPair<FName, int32>, int32> InputsPerPlayerPerTick;
    TArray<FInputRejectRecord> RejectRing;
    TMap<FName, FPlayerInputState> PlayerState;

    FAuthoritativeFrameSummary CurrentFrame;
    FAuthoritativeFrameSummary LastFrame;

    void RecordReject(FName PlayerId, const FClientInputFrame& Input, const FString& Reason);
};
