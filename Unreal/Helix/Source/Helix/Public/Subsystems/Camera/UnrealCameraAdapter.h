#pragma once
#include "ICamera.h"

class UnrealCameraAdapter : public ICamera
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
