#pragma once

class IHelixSubsystem
{
public:
    virtual ~IHelixSubsystem() = default;

    virtual void Initialize() = 0;
    virtual void Update(float FixedDeltaTime) = 0;
    virtual void Shutdown() = 0;
};
