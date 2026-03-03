#pragma once
#include "IVehicle.h"

class UnrealVehicleAdapter : public IVehicle
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
