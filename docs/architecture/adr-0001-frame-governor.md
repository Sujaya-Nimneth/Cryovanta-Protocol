# ADR-0001: Render-frame governor ownership

## Status

Accepted — 2026-11-20

## Context

The director sampled fixed simulation delta and the simulation root sampled wall time again. Manual stepping therefore changed level of detail without measuring a rendered frame.

## Decision

`PlanetarySimulation._process` is the sole live governor sampling owner. It measures elapsed wall time between rendered frames, clamps abnormal intervals, and samples once. `_physics_process` advances fixed simulation only. Director steps publish governor state but never infer frame time from delta. Manual tests use `sample_render_frame` explicitly.

## Alternatives considered

- Keep physics-delta sampling: rejected because it cannot detect render overload.
- Sample in both callbacks: rejected because it double-counts and couples LOD to test loops.

## Consequences

LOD adapts to actual render cost. A fixed 120 Hz simulation may produce multiple ticks per render sample. Headless tests must inject render samples rather than silently changing the governor through simulation ticks.

## Verification

Manual simulation preserves the governor clock; injected overload and recovery samples change LOD within bounds.
