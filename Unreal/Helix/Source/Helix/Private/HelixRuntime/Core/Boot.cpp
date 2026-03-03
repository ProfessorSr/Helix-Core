#include "HelixRuntime/Core/Boot.h"

#include "HelixRuntime/Authorities/DomainSchemaAuthority.h"
#include "HelixRuntime/Authorities/EventAuthority.h"
#include "HelixRuntime/Authorities/GameplayAuthority.h"
#include "HelixRuntime/Authorities/NetworkingAuthority.h"
#include "HelixRuntime/Authorities/ProfilerAuthority.h"
#include "HelixRuntime/Authorities/ReplayCertificationAuthority.h"
#include "HelixRuntime/Authorities/TimeAuthority.h"
#include "HelixRuntime/Runtime/RuntimeEntrypoint.h"
#include "HelixRuntime/Simulation/WorldGraph.h"

FHelixKernel FHelixBootstrap::BuildKernel(const FHelixConfig& SeedConfig)
{
    FHelixKernel Kernel;
    Kernel.Config = MakeShared<FHelixConfig>(SeedConfig);
    Kernel.Config->Lock();

    Kernel.TimeAuthority = MakeShared<FTimeAuthority>();
    Kernel.EventAuthority = MakeShared<FEventAuthority>();
    Kernel.GameplayAuthority = MakeShared<FGameplayAuthority>();
    Kernel.DomainSchemaAuthority = MakeShared<FDomainSchemaAuthority>();
    Kernel.NetworkingAuthority = MakeShared<FNetworkingAuthority>();
    Kernel.ReplayCertificationAuthority = MakeShared<FReplayCertificationAuthority>();
    Kernel.ProfilerAuthority = MakeShared<FProfilerAuthority>();
    Kernel.Simulation = MakeShared<FSimulationState>();

    return Kernel;
}
