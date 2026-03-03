#include "HelixRuntime/Simulation/LockstepBuffer.h"

void FLockstepBuffer::Push(const FLockstepFrame& Frame)
{
    Frames.Add(Frame.Tick, Frame.Hash);
}

bool FLockstepBuffer::Verify(int32 Tick, uint64 Hash) const
{
    const uint64* Existing = Frames.Find(Tick);
    return Existing ? (*Existing == Hash) : false;
}
