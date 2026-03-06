#include "HelixRuntime/Simulation/RewindBuffer.h"

void FRewindBuffer::Push(const FSimulationState& State)
{
    States.Add(State);
    if (States.Num() > Capacity)
    {
        States.RemoveAt(0, States.Num() - Capacity, EAllowShrinking::No);
    }
}

bool FRewindBuffer::GetByTick(int32 Tick, FSimulationState& OutState) const
{
    for (const FSimulationState& State : States)
    {
        if (State.Tick == Tick)
        {
            OutState = State;
            return true;
        }
    }

    return false;
}
