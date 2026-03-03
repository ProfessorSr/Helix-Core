#pragma once
#include "IPhysics.h"

class UnrealPhysicsAdapter : public IPhysics
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
