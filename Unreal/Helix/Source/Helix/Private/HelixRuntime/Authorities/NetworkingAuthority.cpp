#include "HelixRuntime/Authorities/NetworkingAuthority.h"

#include "HelixRuntime/Core/HelixConfig.h"
#include "HelixRuntime/Core/HelixLog.h"

void FNetworkingAuthority::Initialize(const FHelixConfig& Config)
{
    MaxFutureTicks = Config.NetworkingMaxFutureTicks;
    MaxPastTicks = Config.NetworkingMaxPastTicks;
    MaxInputsPerPlayerPerTick = Config.NetworkingMaxInputsPerPlayerPerTick;
    MaxInputsPerTick = Config.NetworkingMaxInputsPerTick;
    RejectBufferSize = FMath::Max(1, Config.NetworkingRejectBufferSize);

    Shutdown();
}

void FNetworkingAuthority::Shutdown()
{
    AcceptedByTick.Reset();
    InputsPerPlayerPerTick.Reset();
    RejectRing.Reset();
    PlayerState.Reset();
    CurrentFrame = FAuthoritativeFrameSummary();
    LastFrame = FAuthoritativeFrameSummary();
}

bool FNetworkingAuthority::QueueClientInput(FName PlayerId, const FClientInputFrame& Input, int32 ServerTick, FString& OutRejectReason)
{
    OutRejectReason.Reset();

    if (Input.Tick > ServerTick + MaxFutureTicks)
    {
        OutRejectReason = TEXT("future_tick");
        RecordReject(PlayerId, Input, OutRejectReason);
        return false;
    }

    if (Input.Tick < ServerTick - MaxPastTicks)
    {
        OutRejectReason = TEXT("past_tick");
        RecordReject(PlayerId, Input, OutRejectReason);
        return false;
    }

    FPlayerInputState& Player = PlayerState.FindOrAdd(PlayerId);
    if (Input.Sequence <= Player.LastSequence)
    {
        OutRejectReason = TEXT("non_monotonic_sequence");
        RecordReject(PlayerId, Input, OutRejectReason);
        return false;
    }

    const TPair<FName, int32> PlayerTickKey(PlayerId, Input.Tick);
    int32& PerPlayerCount = InputsPerPlayerPerTick.FindOrAdd(PlayerTickKey);
    if (PerPlayerCount >= MaxInputsPerPlayerPerTick)
    {
        OutRejectReason = TEXT("player_tick_queue_cap");
        RecordReject(PlayerId, Input, OutRejectReason);
        return false;
    }

    TArray<FQueuedInput>& TickQueue = AcceptedByTick.FindOrAdd(Input.Tick);
    if (TickQueue.Num() >= MaxInputsPerTick)
    {
        OutRejectReason = TEXT("tick_queue_cap");
        RecordReject(PlayerId, Input, OutRejectReason);
        return false;
    }

    TickQueue.Add({ PlayerId, Input });
    ++PerPlayerCount;
    Player.LastSequence = Input.Sequence;
    ++Player.Accepted;

    return true;
}

int32 FNetworkingAuthority::ConsumeAcceptedInputsForTick(int32 Tick, TArray<TPair<FName, FClientInputFrame>>& OutInputs)
{
    OutInputs.Reset();

    TArray<FQueuedInput>* Queue = AcceptedByTick.Find(Tick);
    if (!Queue)
    {
        CurrentFrame.InputCount = 0;
        return 0;
    }

    Queue->Sort([](const FQueuedInput& A, const FQueuedInput& B)
    {
        if (A.Player == B.Player)
        {
            return A.Frame.Sequence < B.Frame.Sequence;
        }
        return A.Player.LexicalLess(B.Player);
    });

    for (const FQueuedInput& Entry : *Queue)
    {
        OutInputs.Add(TPair<FName, FClientInputFrame>(Entry.Player, Entry.Frame));
    }

    const int32 Count = OutInputs.Num();
    AcceptedByTick.Remove(Tick);
    CurrentFrame.InputCount = Count;
    return Count;
}

void FNetworkingAuthority::FinalizeFrame(int32 Tick)
{
    CurrentFrame.Tick = Tick;
    CurrentFrame.Rejects = RejectRing.Num();
    LastFrame = CurrentFrame;
    UE_LOG(LogHelixNet, VeryVerbose, TEXT("[NetworkingAuthority] Tick=%d | Accepted=%d | Rejected=%d"), Tick, LastFrame.InputCount, LastFrame.Rejects);
}

void FNetworkingAuthority::RecordReject(FName PlayerId, const FClientInputFrame& Input, const FString& Reason)
{
    FPlayerInputState& Player = PlayerState.FindOrAdd(PlayerId);
    ++Player.Rejected;

    if (RejectRing.Num() >= RejectBufferSize)
    {
        RejectRing.RemoveAt(0, 1, EAllowShrinking::No);
    }

    RejectRing.Add({ PlayerId, Input.Tick, Input.Sequence, Reason });
    UE_LOG(LogHelixValidation, Warning, TEXT("[Writer] Rejected command | Domain=Networking | Command=%s | Reason=%s"), *Input.Command.ToString(), *Reason);
}
