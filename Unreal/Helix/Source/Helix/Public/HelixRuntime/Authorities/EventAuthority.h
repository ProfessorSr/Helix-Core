#pragma once

#include "CoreMinimal.h"

class FEventAuthority
{
public:
    void Initialize() {}
    void Shutdown() { EventsThisTick = 0; }
    void ProcessTick() { EventsThisTick = 0; }

    void RecordEvent() { ++EventsThisTick; }
    int32 GetEventsThisTick() const { return EventsThisTick; }

private:
    int32 EventsThisTick = 0;
};
