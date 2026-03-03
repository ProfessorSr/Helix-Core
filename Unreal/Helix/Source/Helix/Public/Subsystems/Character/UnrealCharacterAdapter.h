#pragma once
#include "ICharacter.h"

class UnrealCharacterAdapter : public ICharacter
{
public:
    void Initialize() override;
    void Update(float FixedDeltaTime) override;
    void Shutdown() override;
};
