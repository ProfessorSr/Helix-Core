// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Engine/EngineTypes.h"
#include "HelixCore.h"
#include "Subsystems/Time/UnrealTimeAdapter.h"
#include "Subsystems/Input/UnrealInputAdapter.h"
#include "Subsystems/Event/UnrealEventAdapter.h"
#include "Subsystems/World/UnrealWorldAdapter.h"

#include "Subsystems/Physics/UnrealPhysicsAdapter.h"
#include "Subsystems/Vehicle/UnrealVehicleAdapter.h"
#include "Subsystems/Character/UnrealCharacterAdapter.h"
#include "Subsystems/Camera/UnrealCameraAdapter.h"
#include "Subsystems/Animation/UnrealAnimationAdapter.h"
#include "Subsystems/AI/UnrealAIAdapter.h"

#include "Subsystems/Climate/UnrealClimateAdapter.h"
#include "Subsystems/Audio/UnrealAudioAdapter.h"
#include "Subsystems/Lighting/UnrealLightingAdapter.h"

#include "Subsystems/Networking/UnrealNetworkingAdapter.h"
#include "Subsystems/Replication/UnrealReplicationAdapter.h"
#include "Subsystems/Save/UnrealSaveLoadAdapter.h"
#include "Subsystems/Economy/UnrealEconomyAdapter.h"
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

    UnrealTimeAdapter Time;
    UnrealInputAdapter Input;
    UnrealEventAdapter Event;
    UnrealWorldAdapter World;

    UnrealPhysicsAdapter Physics;
    UnrealVehicleAdapter Vehicle;
    UnrealCharacterAdapter Character;
    UnrealCameraAdapter Camera;
    UnrealAnimationAdapter Animation;
    UnrealAIAdapter AI;

    UnrealClimateAdapter Climate;
    UnrealAudioAdapter Audio;
    UnrealLightingAdapter Lighting;

    UnrealNetworkingAdapter Networking;
    UnrealReplicationAdapter Replication;
    UnrealSaveLoadAdapter SaveLoad;
    UnrealEconomyAdapter Economy;
};
