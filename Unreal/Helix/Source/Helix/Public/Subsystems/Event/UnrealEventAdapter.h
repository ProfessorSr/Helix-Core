#pragma once
#include "IEvent.h"

class UnrealEventAdapter : public IEvent
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
