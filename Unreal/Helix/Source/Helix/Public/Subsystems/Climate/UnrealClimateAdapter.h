#pragma once
#include "IClimate.h"

class UnrealClimateAdapter : public IClimate
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
