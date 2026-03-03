#pragma once
#include "IInput.h"

class UnrealInputAdapter : public IInput
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
