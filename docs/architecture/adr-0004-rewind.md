# ADR-0004: Coherent fixed-capacity sortie checkpoints

## Status

Accepted — 2026-11-20

## Context

The 64-slot recorder restored position, velocity, temperature, hull, and guidance mode but silently discarded attitude, angular velocity, fuel, mission progress, power, weapons, and pooled entities.

## Decision

Retain the recorder's 64-slot capacity and scalar flight API. Add a checkpoint coordinator with preallocated packed state for the complete sortie: ship transform and velocity, thermal/propellant/power/weapon state, guidance, mission counters, gear/radar/proximity state, waypoints, targets, projectiles, impacts, recorder scalar metadata, and floating-origin bookkeeping. Restore the checkpoint as one transaction. Rewind stabilizes attitude by restoring the captured attitude and clearing angular velocity. Existing scalar-only snapshots remain supported as reduced flight snapshots and do not claim to restore sortie state.

## Alternatives considered

- Rename the feature to position reset: rejected because the product already promises flight rewind.
- Allocate serialized dictionaries per sample: rejected because it violates the fixed-storage hot-path contract.
- Restore only the ship: rejected because mission and resource state become inconsistent.

## Consequences

Checkpoint storage is allocated at setup. Terrain is regenerated from deterministic planet/origin state rather than copied into every checkpoint. Rebase updates checkpoint positions without changing velocities. Pool free lists are reconstructed from restored occupancy.

## Verification

Full-state equality after mutation/restore, repeated restore, rebase safety, empty-checkpoint rejection, and fixed storage capacity are tested.
