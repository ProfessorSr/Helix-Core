#pragma once
#include "IAnimation.h"

class UnrealAnimationAdapter : public IAnimation
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
