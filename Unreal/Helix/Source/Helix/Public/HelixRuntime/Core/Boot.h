#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Core/HelixConfig.h"

struct FHelixKernel;

class FHelixBootstrap
{
public:
    static FHelixKernel BuildKernel(const FHelixConfig& SeedConfig);
};
