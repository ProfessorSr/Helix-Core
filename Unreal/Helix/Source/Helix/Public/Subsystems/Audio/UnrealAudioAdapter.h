#pragma once
#include "IAudio.h"

class UnrealAudioAdapter : public IAudio
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
