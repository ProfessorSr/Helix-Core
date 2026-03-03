# Helix Rebuild Spec (C++ / Unreal)

This document now tracks the Unreal C++ rebuild target.

Primary spec:
- `Docs/HelixRebuild_UnrealCpp.md`

Use that file as the source of truth for rebuilding the same Helix architecture in Unreal C++ (not a portability shim).

## Scope
- Rebuild the exact deterministic runtime model in Unreal C++.
- Preserve layer ownership, authority boundaries, fixed-step scheduling, and reader/writer host adapters.
- Preserve replay/hash certification behavior.

## Required parity
- Same seed + same ordered inputs must produce identical per-tick state hashes.
- Runtime lifecycle must remain:
  1. Bootstrap: config only
  2. RuntimeHost: subsystem wiring only
  3. Scheduler: deterministic time/event/gameplay/subsystem tick ownership

## Direct link
- See `Docs/HelixRebuild_UnrealCpp.md` for full implementation blueprint.
