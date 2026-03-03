#pragma once
#include "IAI.h"

class UnrealAIAdapter : public IAI
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
