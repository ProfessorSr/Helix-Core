// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Engine/EngineTypes.h"
#include "HelixCore.h"
#include "HelixHost.generated.h"

UCLASS()
class HELIX_API AHelixHost : public AActor
{
    GENERATED_BODY()
    
public:    
    // Sets default values for this actor's properties
    AHelixHost();

protected:
    // Called when the game starts or when spawned
    virtual void BeginPlay() override;

public:    
    // Called every frame
    virtual void Tick(float DeltaTime) override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
private:

    FHelixCore Core;
};
