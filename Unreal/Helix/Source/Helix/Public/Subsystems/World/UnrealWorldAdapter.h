#pragma once
#include "IWorld.h"

class UnrealWorldAdapter : public IWorld
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
