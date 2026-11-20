# ADR-0007: Terrain Backend, Simplex Parity, and Zero-Allocation Buffering

## Status

Accepted — 2026-11-20

## Context

Cryovanta Protocol generates `34x34` skirted cube-sphere terrain chunks (`VERTEX_COUNT = 1156`, `INDEX_COUNT = 6534`, `TRIANGLE_COUNT = 2178`, `SKIRT_FRACTION = 0.05`) using both a Vulkan compute shader ([planet_chunk.glsl](../../planet_chunk.glsl)) and a deterministic GDScript builder ([TerrainMeshBuilder.gd](../../TerrainMeshBuilder.gd)). Three constraints surfaced during Phase 2–3 hardening:

1. Headless verification runs without a live GPU (`DisplayServer.get_name() == "headless"`), requiring an exact CPU fallback (`ComputeChunkDispatcher.dispatch_chunk()`).
2. A single-chunk CPU build took `~12,648.6 µs` (`~12.65 ms`) in single-thread macOS headless benchmarking (`> 8.333 ms` 120 FPS budget), proving terrain builds cannot run synchronously on the main simulation thread.
3. Three pre-existing CPU generator defects threatened parity and memory determinism: a simplex sector typo at `TerrainMeshBuilder.gd` (`i2y = 1` instead of `i2z = 1`), per-build heap allocation of `var twx: Array[Vector3] = []`, and retired staging exhaustion under burst LOD cancellation in `PlanetStreamer._cancel_slot_job()`.

## Decision

1. **Dual Backend with Shared `std430` Contract:**
   - **Vulkan Compute (`ComputeChunkDispatcher` + `planet_chunk.glsl`):** Dispatches `5 x 5 x 1` workgroups of `8 x 8 x 1` invocations writing `VERTEX_COUNT = 1156` interleaved `PlanetVertex` structs (`VERTEX_STRIDE_BYTES = 32`, `STORAGE_BUFFER_SIZE_BYTES = 36992`, `48`-byte push constants).
   - **Deterministic CPU Fallback (`TerrainMeshBuilder`):** Matches `planet_chunk.glsl` simplex gradient/hash math, including the corrected `i1z = 1; i2x = 1; i2z = 1` simplex sector branch (`planet_chunk.glsl:127`).
2. **Pre-Allocated Per-Slot Scratch & Staging Pools:**
   - `TerrainMeshBuilder.init_builder()` pre-allocates `64` reusable `PackedVector3Array` buffers in `_twx_pool` (indexed by `staging_id` from `PlanetStreamer._build_chunk_job()`), paired with `4` worker pool slots (`MAX_WORKERS = 4`) so concurrent `ChunkTaskScheduler` builds perform zero steady-state heap allocations.
   - `PlanetStreamer._cancel_slot_job()` invokes `_release_retired_staging()` before checking `retired_count < JOB_CAPACITY` (`JOB_CAPACITY = 64`), preventing retired staging slot leaks under rapid camera sweeps.
3. **Exterior Visibility Without Winding Churn:**
   - `PlanetSurfaceMaterial.gd` uses `render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;` with signed elevation remapping (`* 0.5 + 0.5`) so CCW terrain quads (`test_phase2` Tier 1.3 contract) remain visible externally without rewriting physics collider winding.

## Alternatives Considered

- **Removing CPU fallback and requiring Vulkan compute everywhere:** Rejected because headless CI verification and non-compute fallback devices require deterministic CPU geometry and `ConcavePolygonShape3D` collider baking.
- **Per-job mutex around one shared `twx` array:** Rejected because mutex contention stalls the `4` worker threads.

## Consequences

- Steady-state per-step streaming management averages `65.4 µs` at `max_lod = 2` in headless benchmarking while delegating expensive `~12.6 ms` chunk synthesis to `<= 4` background threads.
- Real Vulkan compute dispatch time (`use_gpu = true`) on Snapdragon 8 Elite Gen 5 / Adreno 840 remains `NOT ASSESSED` until on-device profiling runs.

## Verification

- `test_phase2_terrain_gravity_headless.gd` (`1410/1410`), `test_phase3_streaming_projectiles_headless.gd` (`2640/2640`), `test_adversarial_m13_challenger1.gd` (`2365/2365`), `test_adversarial_m13_challenger2.gd` (`8066/8066`), and `test_adversarial_m13_reviewer2.gd` (`135/135`) all pass with zero failures.
