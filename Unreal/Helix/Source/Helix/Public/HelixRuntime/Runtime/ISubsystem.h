#pragma once

#include "CoreMinimal.h"

struct FHelixKernel;
class IReader;
class IWriter;

class ISubsystem
{
public:
    virtual ~ISubsystem() = default;
    virtual void Init(FHelixKernel& Kernel, TSharedPtr<IReader> Reader, TSharedPtr<IWriter> Writer) = 0;
    virtual void Start() = 0;
    virtual void Tick(double FixedDt) = 0;
    virtual void Stop() = 0;
    virtual void SetControlSource(FName Source) = 0;
    virtual FName GetControlSource() const = 0;
};

class FHelixSubsystemBase : public ISubsystem
{
public:
    void SetControlSource(FName Source) override { ControlSource = Source; }
    FName GetControlSource() const override { return ControlSource; }

protected:
    FName ControlSource = TEXT("Helix");
};
