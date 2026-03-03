#pragma once
#include "ILighting.h"

class UnrealLightingAdapter : public ILighting
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
