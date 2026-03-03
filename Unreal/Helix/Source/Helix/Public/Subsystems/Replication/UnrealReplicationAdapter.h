#pragma once
#include "IReplication.h"

class UnrealReplicationAdapter : public IReplication
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
