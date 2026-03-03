#pragma once
#include "IEconomy.h"

class UnrealEconomyAdapter : public IEconomy
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
