# Helix Rebuild Blueprint (C++ / Unreal Engine)

## Goal
Rebuild the current Helix runtime architecture in Unreal C++ with behavior parity:
- deterministic fixed-step simulation
- strict layer boundaries
- authority-driven lifecycle
- host adapters as translators
- replay/hash certification

---

## 1. Unreal Project Structure

```text
Source/HelixRuntime/
  Public/
    Core/
      HelixConfig.h
      Scheduler.h
      Registry.h
      Boot.h
    Authorities/
      TimeAuthority.h
      EventAuthority.h
      GameplayAuthority.h
      DomainSchemaAuthority.h
      NetworkingAuthority.h
      ReplayCertificationAuthority.h
      ProfilerAuthority.h
    Simulation/
      WorldGraph.h
      SpatialHierarchy.h
      PhysicsPipeline.h
      Broadphase.h
      CollisionPipeline.h
      ConstraintSolver.h
      SnapshotDiff.h
      RewindBuffer.h
      LockstepBuffer.h
      DevTools.h
      ContentValidator.h
    Runtime/
      RuntimeHost.h
      RuntimeEntrypoint.h
      SubsystemManifest.h
      ISubsystem.h
      IReader.h
      IWriter.h
    Subsystems/
      Core/*.h
      Expansion/*.h
      Enterprise/*.h
      Simulation/*.h
    Hosts/
      Core/*.h
      Expansion/*.h
      Enterprise/*.h
      Simulation/*.h
  Private/
    ... mirrored cpp files ...
```

---

## 2. Core Types (exact contract intent)

## `FHelixKernel`
```cpp
struct FHelixKernel
{
  TSharedPtr<FHelixConfig> Config;
  TSharedPtr<FTimeAuthority> TimeAuthority;
  TSharedPtr<FEventAuthority> EventAuthority;
  TSharedPtr<FGameplayAuthority> GameplayAuthority;
  TSharedPtr<FDomainSchemaAuthority> DomainSchemaAuthority;
  TSharedPtr<FNetworkingAuthority> NetworkingAuthority;
  TSharedPtr<FReplayCertificationAuthority> ReplayCertificationAuthority;
  TSharedPtr<FProfilerAuthority> ProfilerAuthority;
  TSharedPtr<FSimulationState> Simulation;
};
```

## `ISubsystem`
```cpp
class ISubsystem
{
public:
  virtual ~ISubsystem() = default;
  virtual void Init(FHelixKernel& Kernel, TSharedPtr<IReader> Reader, TSharedPtr<IWriter> Writer) = 0;
  virtual void Start() = 0;
  virtual void Tick(double FixedDt) = 0;
  virtual void Stop() = 0;
  virtual void SetControlSource(FName Source) = 0; // Host / Helix
  virtual FName GetControlSource() const = 0;
};
```

## `IReader` / `IWriter`
```cpp
class IReader { public: virtual void Initialize(FHelixKernel& Kernel)=0; virtual void Tick(double Dt)=0; virtual void Shutdown()=0; };
class IWriter { public: virtual void Initialize(FHelixKernel& Kernel)=0; virtual void Enqueue(FName Command, const FInstancedStruct& Payload)=0; virtual void Tick(double Dt)=0; virtual void Shutdown()=0; };
```

---

## 3. Lifecycle Order (must match)

1. Bootstrap builds kernel authorities + config init/lock.
2. RuntimeEntrypoint:
   - ensure authorities exist
   - init schema authority
   - init event/gameplay/network/profiler/replay authorities
   - create simulation state
   - start RuntimeHost (manifest load)
   - start Scheduler
3. Scheduler per fixed tick:
   - `TimeAuthority.Advance()`
   - `EventAuthority.ProcessTick()`
   - `GameplayAuthority.ProcessTick()`
   - tick subsystems in `Registry.GetOrdered()`
4. Stop:
   - stop runtime host reverse order
   - shutdown/reset authorities
   - clear simulation
   - reset scheduler state

Use `FTSTicker` or `UWorldSubsystem::Tick` accumulator for fixed-step execution.

---

## 4. Determinism Requirements

1. Never iterate unordered maps in simulation paths without sorting keys.
2. Entity IDs are monotonic integer IDs.
3. Broadphase outputs sorted candidate pairs.
4. Narrowphase outputs canonical ordered pair `(A < B)`.
5. Collision/constraint iterations are fixed and config-driven.
6. Hash over deterministic world snapshot representation only.

Unreal notes:
- Avoid physics engine state for Helix simulation path.
- Keep simulation in plain structs (`FVector3d` + POD-like components).
- Apply host transforms only in writer stage.

---

## 5. Unreal Class Mapping

1. **Runtime Entrypoint**
   - `UHelixRuntimeSubsystem : UGameInstanceSubsystem`
   - own Start/Stop and public control APIs.

2. **Host adapters**
   - Readers/Writers as C++ classes; for engine interaction use `UWorld*`, `AActor*`, `USceneComponent*`.

3. **Debug panel**
   - `UUserWidget` + binding to runtime debug payload.
   - Update from runtime subsystem every N ms.

4. **Manifest**
   - C++ static registry or DataAsset (`UHelixSubsystemManifestDataAsset`) with:
     - Name, Domain, Phase, Dependencies, SubsystemClass, ReaderClass, WriterClass.

---

## 6. Physics Pipeline in Unreal

Recreate the same modules:
1. `FBroadphase` (sweep-and-prune on X axis)
2. `FCollisionPipeline` (integrate + resolve)
3. `FConstraintSolver` (distance constraints, damping)
4. `FPhysicsPipeline` orchestrator

Config keys to include:
- `PhysicsFixedStep`
- `PhysicsMaxSubsteps`
- `PhysicsCollisionIterations`
- `PhysicsConstraintIterations`
- `PhysicsMaxSpeed`
- `PhysicsPenetrationSlop`
- `PhysicsBaumgarte`
- `PhysicsMaxCorrection`
- `PhysicsSleepVelocity`
- `PhysicsSleepFrames`
- `PhysicsMaxCollisionRecordsPerStep`
- `PhysicsCaptureStateDiff`

---

## 7. Networking Authority Finalization (Unreal)

Implement server-authoritative queue:
- input sequence monotonic per player
- accepted tick window (`MaxFutureTicks`, `MaxPastTicks`)
- per-tick and per-player queue caps
- reject ring buffer
- player state counters
- authoritative frame summary (tick/hash/input count/rejects)

Integrate with Unreal net layer:
- RPC from client -> server: input packets (`Tick, Sequence, InputFrame`)
- server feeds `NetworkingAuthority.QueueClientInput`
- gameplay authority consumes only accepted inputs

---

## 8. Tooling / Editor UX

1. Build `FDebugInspectorData` payload from:
- overlay
- diff
- profiler frame
- networking frame + rejects

2. Expose to:
- in-game widget (`UUserWidget`)
- editor debug window (optional Slate panel)

3. Add runtime toggle CVars:
- `helix.DebugPanel 0|1`
- `helix.Profile 0|1`
- `helix.AuthoritativeNet 0|1`

---

## 9. Content Pipeline Hardening

Implement `FContentValidator`:
- sanitize component payloads (`Body`, `Bounds`, `Constraint`)
- reject NaN/Inf
- clamp ranges (mass, restitution, friction, etc.)

Apply at:
- entity creation
- component mutation APIs

---

## 10. Stress / Certification

Add runtime APIs:
- `RunSimulationStressTest(EntityCount, Steps, Radius, Amplitude)`
- `BeginReplayCertification(ScenarioId)`
- `EndReplayCertification()`
- `CertifyReplayAgainstBaseline(Certificate)`

Output:
- average step ms
- max collisions
- max broadphase pairs
- memory usage
- replay digest

---

## 11. Minimum Parity Acceptance

1. Same seed + same input frames => identical per-tick state hash sequence.
2. Same scenario => identical replay certificate digest.
3. Dependency cycle in manifest fails fast.
4. Subsystem source switching works (`Host`/`Helix`).
5. Debug inspector exposes profiler/networking/physics metrics.

---

## 12. Build Plan (recommended)

1. Core authorities + scheduler + registry.
2. RuntimeHost + manifest + dependency topo sort.
3. WorldGraph + physics pipeline.
4. Networking authority + gameplay input loop.
5. Replay certification.
6. Debug panel + stress harness.

