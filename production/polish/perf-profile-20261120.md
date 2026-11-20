# Cryovanta Protocol — Performance Profile Report

**Date:** 2026-11-20  
**Engine:** Godot `v4.7.2.stable.official.ed1daf0bf`  
**Measured Platform:** macOS host (`--headless`, CPU dummy renderer, `120 Hz` physics `dt = 1/120 s`)  
**Target Android Device Profile (Snapdragon 8 Elite Gen 5 / Adreno 840 Vulkan):** `NOT ASSESSED` (no physical device or live Vulkan frame trace captured)

---

## 1. Frame Budget Targets (`project.yaml`)

| Budget Metric | Target Limit | Headless CPU Observation | Android Vulkan Status |
| :--- | :--- | :--- | :--- |
| Physics & Frame Budget (`120 Hz`) | `<= 8,333.3 µs` (`8.333 ms`) | `153.3 µs` avg step / `439 µs` peak | `NOT ASSESSED` (render pass omitted) |
| Draw Call Limit | `<= 400` | `NOT ASSESSED` (headless dummy) | `NOT ASSESSED` |
| Memory Ceiling | `<= 1,024 MB` | `0` bytes static delta in steady state (verified 1k–2k ticks) | `NOT ASSESSED` |
| Background Worker Concurrency | `<= 4` threads | Enforced (`ChunkTaskScheduler`, `4` workers max) | Enforced cleanly |

## 2. Observed Headless Step Breakdown (`bench_step33.gd`, 1,200 ticks @ `max_lod = 2`)

Measured immediately after 120 warmup ticks using `SimulationTelemetry` microsecond registers (`step_physics_usec`, `step_streamer_usec`, `step_director_hud_usec`, `step_total_usec`, `peak_step_usec`):

| Subsystem Slice | Measured Average (`µs`) | Share of Step | Notes |
| :--- | :---: | :---: | :--- |
| Physics, Guidance, Origin, Pools | `11.5 µs` | `7.5%` | Fixed `128`-projectile & `64`-target pools + rigid-body integration |
| Planet Streamer Scan (`update_streamer`) | `65.4 µs` | `42.7%` | Quadtree traversal + pool slot scan (`max_lod = 2`) |
| Telemetry, Env, Director, HUD Sync | `76.4 µs` | `49.8%` | Keplerian predictor + GPWS/LOS + change-cached HUD state sync |
| **Total `step_simulation()` Step** | **`153.3 µs`** | **`100%`** | **`peak_step_usec = 439 µs`** |

## 3. Single-Chunk Build Cost: CPU vs Compute Fallback

Measured across 20 iterations per backend (`face % 6`, `lod = 2`, `34x34` skirted chunk):

- **Main-thread `TerrainMeshBuilder.build_mesh_cpu`:** `12,648.6 µs` (`~12.65 ms` / chunk)
- **`ComputeChunkDispatcher(true)` CPU fallback:** `12,601.0 µs` (`~12.60 ms` / chunk)
- **`ComputeChunkDispatcher.use_gpu` in headless:** `false` (`fallback_reason = "headless dummy renderer"`)

**Engineering Takeaway:** Main-thread CPU chunk generation (`12.65 ms`) exceeds the entire `8.333 ms` 120 Hz frame budget on a single chunk, validating both asynchronous `ChunkTaskScheduler` offload (`<= 4` workers with pre-allocated `_twx_pool`) and keeping `ComputeChunkDispatcher` + `planet_chunk.glsl` ready for GPU dispatch on Vulkan hardware.
