#pragma once
#include "ITime.h"

class UnrealTimeAdapter : public ITime
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
