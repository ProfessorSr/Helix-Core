#pragma once

#include "CoreMinimal.h"

struct FLockstepFrame
{
    int32 Tick = 0;
    uint64 Hash = 0;
};

class FLockstepBuffer
{
public:
    void Push(const FLockstepFrame& Frame);
    bool Verify(int32 Tick, uint64 Hash) const;

private:
    TMap<int32, uint64> Frames;
};
