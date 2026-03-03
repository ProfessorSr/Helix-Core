#pragma once
#include "INetworking.h"

class UnrealNetworkingAdapter : public INetworking
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
