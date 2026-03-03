#pragma once

#include "CoreMinimal.h"
#include "HelixRuntime/Authorities/NetworkingAuthority.h"
#include "HelixRuntime/Authorities/ProfilerAuthority.h"
#include "HelixRuntime/Simulation/SnapshotDiff.h"
#include "HelixRuntime/Simulation/PhysicsPipeline.h"

struct FDebugInspectorData
{
    int32 Tick = 0;
    uint64 StateHash = 0;
    FSnapshotDiffResult Diff;
    FSubsystemProfileFrame Profile;
    FAuthoritativeFrameSummary Network;
    int32 RejectCount = 0;
    FPhysicsStepStats Physics;
};
