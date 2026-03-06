// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Engine/EngineTypes.h"
#include "HelixCore.h"
#include "HelixUnreal.generated.h"

UCLASS()
class HELIX_API AHelixUnreal : public AActor
{
    GENERATED_BODY()

public:
    AHelixUnreal();

protected:
    virtual void BeginPlay() override;

public:
    virtual void Tick(float DeltaTime) override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

private:
    FHelixCore Core;
};
