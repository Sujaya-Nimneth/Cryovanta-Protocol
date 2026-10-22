# Project: Cryovanta Protocol - Live Streaming, Projectiles, Compute & Radar (Phase 3)

## Architecture
Cryovanta Protocol is a 64-bit precision procedural space simulation targeting high-performance mobile Vulkan 1.4 rendering (Godot 4.7).
The architecture decouples planetary terrain generation from local physics via coordinate rebasing:
- **Terrain Quadtree System**: `PlanetManager.gd`, `QuadtreeNode.gd`, `PlanetMath.gd`, `ChunkPoolManager.gd`, and compute shaders generate continuous spherical terrain with zero runtime heap allocations in split and bounds evaluation paths.
- **Floating Origin System**: `FloatingOrigin.gd` monitors the player vessel. When $\|\vec{x}_{\text{player}}\| > 2000.0\text{ m}$, it subtracts the offset from player, registered entities (with ancestor hierarchy guards), and the planet center offset, preserving topological and visual quadtree continuity without physics velocity spikes ($\Delta v < 10^{-4}$). Dual 64-bit equivalent sector coordinates (`Vector3i` sector + `Vector3` wrapped local remainder) prevent float precision loss across astronomical distances.
- **6-DOF Flight & Planetary Gravity**: `SpaceshipController.gd` extends `RigidBody3D` with 6 degrees of freedom (surge, sway, heave, pitch, yaw, roll) and radial inverse-square planetary gravity with zero per-frame heap allocations and double-rebase deduplication guards.
- **Pure Static Math Libraries**: `AtmosphereMath.gd` encapsulates barometric density, quadratic aerodynamic drag, and inverse-square radial gravity acceleration. `PlanetMath.gd` precomputes cube-face basis tangents and provides primitive zero-allocation bounding math.
- **Terrain Mesh & Skirt System**: `TerrainMeshBuilder.gd` emits exact 48-byte `std430` push constants matching `planet_chunk.glsl` and generates 34x34 vertex grids (32x32 interior + 1-vertex perimeter skirt, 1,156 vertices, 6,534 indices) with 5% skirt extrusion toward planet center and zero runtime heap allocations.
- **Pre-Allocated Collider Pool**: `ColliderPoolManager.gd` pre-allocates 64 `StaticBody3D` / `ConcavePolygonShape3D` slots. Leaf quadtree chunks at `lod_level >= max_lod - 1` acquire/release colliders with admission gating to prevent pool exhaustion and guarantee zero orphan colliders.
- **Worker Thread Scheduler**: `ChunkTaskScheduler.gd` bounds background worker threads to a strict concurrency ceiling of 4 (`MAX_CONCURRENT_WORKERS = 4`) using a fixed-capacity 64-slot ring buffer with zero steady-state heap allocations.
- **Live Terrain Streaming**: `PlanetStreamer.gd` bridges quadtree leaves to 256 pre-allocated `MeshInstance3D` slots, queues asynchronous mesh/collider generation through worker-indexed scratch buffers, drains jobs before LOD mutation, and resets hidden slots on split or merge.
- **Fixed Projectile Ring Buffer**: `ProjectilePoolManager.gd` pre-allocates 128 projectile states and visual markers, supports O(1) acquisition/release, radial gravity, terrain ray impacts, and velocity-continuous origin rebasing.
- **Compute Dispatcher & CPU Fallback**: `ComputeChunkDispatcher.gd` matches the `planet_chunk.glsl` `(5, 5, 1)` workgroup contract and exact 36,992-byte `std430` vertex buffer. Headless/dummy rendering deterministically falls back to `TerrainMeshBuilder.build_mesh_cpu()`.
- **Weapon & Radar**: `SpaceshipWeaponSystem.gd` inherits ship velocity into pooled projectiles and measures surface altitude with one reused radial `PhysicsRayQueryParameters3D` against baked terrain colliders.
- **Automated Verification**: Comprehensive headless test suites validate end-to-end functionality, quadtree pool stability, 48-byte std430 alignment, mesh topology, collider pool integrity, worker thread bounds, radial gravity continuity, memory leaks, and line counts.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Floating Origin Rebase Trigger | Detect when player position exceeds 2000m threshold and trigger rebase | M1 | ORIGINAL_REQUEST R1 |
| F2 | Planet Center Offset Interface | Update planet center offset in PlanetManager to preserve quadtree continuity | M1 | ORIGINAL_REQUEST R1 |
| F3 | World Entity & Camera Rebasing | Reposition camera and registered world entities in the same frame | M1 | ORIGINAL_REQUEST R1 |
| F4 | Zero Velocity Spike Continuity | Preserve linear and angular velocities across rebase frame with <1e-4 tolerance | M1 | ORIGINAL_REQUEST R1, R4 |
| F5 | 6-DOF Flight Controls | Implement pitch, yaw, roll, forward/back, strafe, vertical ascent/descent | M2 | ORIGINAL_REQUEST R2 |
| F6 | Zero Runtime Allocations | Zero heap allocations in `_physics_process` (verified via static memory delta) | M2 | rules.md §1, ORIGINAL_REQUEST R2 |
| F7 | Vacuum Boundary Drag Zeroing | Atmospheric density and drag strictly zero when altitude >= atmospheric ceiling | M3 | ORIGINAL_REQUEST R3 |
| F8 | Continuous Barometric Drag Profile | Smooth density scaling from surface to ceiling and speed-squared drag force | M3 | ORIGINAL_REQUEST R3 |
| F9 | Script Line Count Guardrail | All newly added scripts strictly <= 250 lines | M1-M3 | rules.md §3, ORIGINAL_REQUEST R4 |
| F10 | Frequent Atomic Git Commits | Descriptive atomic commits documenting each logical change | M1-M4 | ORIGINAL_REQUEST R5 |
| F11 | Headless Automated Test Suite | Opaque-box test suite executing headless with zero exit code | M4 | ORIGINAL_REQUEST R4 |
| F12 | Zero-Allocation Quadtree Math | Precomputed tangents/bitangents and primitive center/radius bounds math | M6 | Follow-up R1 |
| F13 | 64-Bit Sector Coordinate Tracking | Dual Vector3i sector + Vector3 local offset representation for 2000m rebasing | M6 | Follow-up R2 |
| F14 | Hierarchy & Double-Rebase Guards | Ancestor check preventing child double-shifts and frame rebase deduplication | M6 | Follow-up R3 |
| F15 | Mobile Feature Configuration | Align project.godot features profile with Vulkan Mobile renderer target | M6 | Follow-up R4 |
| F16 | 48-Byte std430 Push Constants | Exact 48-byte layout (3x vec4, 16-byte aligned) matching planet_chunk.glsl | M7 | Phase 2 Follow-up R1 |
| F17 | 34x34 Skirted Chunk Mesh | 1,156 vertices, 6,534 indices, 5% radial skirt toward planet center | M7 | Phase 2 Follow-up R1 |
| F18 | Zero-Allocation Mesh Buffers | Pre-allocated static index buffer & reused vertex/normal buffers | M7 | Phase 2 Follow-up R1 |
| F19 | 64-Slot Terrain Collider Pool | Pre-allocated ring buffer with O(1) acquire/release of ConcavePolygonShape3D | M8 | Phase 2 Follow-up R2 |
| F20 | Quadtree Collider Gating | Admission gating in split/merge for lod >= max_lod - 1, 0 orphan colliders | M8 | Phase 2 Follow-up R2 |
| F21 | Max-4 Worker Task Scheduler | Bounded 4-thread scheduler with 64-slot ring buffer and 0 steady-state allocs | M9 | Phase 2 Follow-up R3 |
| F22 | Radial Inverse-Square Gravity Math | $g(r) = -g_0 (R/r)^2 \hat{r}$ with $r \ge R$ clamping | M10 | Phase 2 Follow-up R4 |
| F23 | Spaceship Planetary Gravity | Integration into SpaceshipController with zero velocity spikes across 2000m rebases | M10 | Phase 2 Follow-up R4 |
| F24 | Automated Phase 2 Test Suite | Headless test runner test_phase2_terrain_gravity_headless.gd exiting code 0 | M11 | Phase 2 Follow-up R5 |
| F25 | Full System Integrity & Hardening | Adversarial tests, line count checks (<=250), Phase 1 backward compatibility | M12 | Phase 2 Follow-up R5 |
| F26 | Thread-Safe Per-Worker Scratch Buffers | Pre-allocated 4-worker scratch buffer sets (MAX_WORKERS = 4, slot_idx in [0..3]) preventing geometry data races | M13 | Phase 2 Hardening R1 |
| F27 | Exact GLSL FBM Noise Parity | Strict parity with planet_chunk.glsl: octave step 1013904223, amp 0.5, freq *= 2.02, unnormalized | M13 | Phase 2 Hardening R1 |
| F28 | Automatic Cancelled Slot Reclamation | Auto-reclaim of cancelled/completed slots during poll() and worker thread index tracking | M13 | Phase 2 Hardening R2 |
| F29 | Chunk Collider Origin Alignment & Reset | set_collider_origin() positioning bodies at chunk sea origin and reset to Vector3.ZERO on release | M13 | Phase 2 Hardening R3 |
| F30 | Live Quadtree Mesh & Collider Streaming | `PlanetStreamer.gd` coordinates 256 pooled visuals, asynchronous jobs, worker scratch slots, and split/merge cancellation | M14 | Phase 3 R1 |
| F31 | 128-Slot Projectile Ring Buffer | Flat pre-allocated state, O(1) free stack, 128 pooled markers, one reused ray query, gravity and impact stepping | M15 | Phase 3 R2 |
| F32 | Vulkan Compute Dispatcher Fallback | `(5, 5, 1)` dispatch contract, 36,992-byte std430 parity, RenderingDevice probe, deterministic CPU fallback | M16 | Phase 3 R3 |
| F33 | Spaceship Weapon & Radar | Ship-relative muzzle velocity inheritance, origin-rebase continuity, radial terrain altimeter with one reused query | M17 | Phase 3 R4 |
| F34 | Phase 3 Automated Verification | Five-tier headless suite covering streaming, projectiles, compute parity, radar, memory, line counts, and regressions | M18 | Phase 3 R5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Floating Origin System | `FloatingOrigin.gd`, update `PlanetManager.gd` | None | DONE |
| M2 | 6-DOF Spaceship Controller | `SpaceshipController.gd` (RigidBody3D, zero allocations) | None | DONE |
| M3 | Dynamic Atmospheric Drag | `AtmosphereMath.gd` and integration into `SpaceshipController.gd` | M2 | DONE |
| M4 | Headless E2E Test Suite | `test_floating_origin_headless.gd` (Tiers 1-4) | M1, M2, M3 | DONE |
| M5 | Final Verification & Hardening | Adversarial tests (Tier 5), Reviewer & Auditor gates | M1, M2, M3, M4 | DONE |
| M6 | Phase 1 Hardening & Optimization | Zero-allocation math, 64-bit sector tracking, hierarchy guards, mobile profile | M1-M5 | DONE |
| M7 | Skirted Mesh & Push Constants | `TerrainMeshBuilder.gd` (34x34 grid, std430 push constants, CPU generator) | None | DONE |
| M8 | Terrain Collider Pool & Quadtree | `ColliderPoolManager.gd`, update `PlanetManager.gd`, `QuadtreeNode.gd` | M7 | DONE |
| M9 | 4-Worker Task Scheduler | `ChunkTaskScheduler.gd` (max 4 threads, ring buffer, 0 allocs) | None | DONE |
| M10 | Radial Planetary Gravity | Update `AtmosphereMath.gd`, `SpaceshipController.gd` | None | DONE |
| M11 | Phase 2 Headless Test Suite | `test_phase2_terrain_gravity_headless.gd` (Tiers 1-5) | M7, M8, M9, M10 | DONE |
| M12 | System Hardening & Forensic Audit | Verification across all suites, script line counts, forensic audit | M1-M11 | DONE |
| M13 | Phase 2 Hardening | Thread-Safe Buffers, GLSL FBM Parity, Cancelled Slot Reclamation, Collider Origin Alignment, Headless Tests | M7-M12 | DONE |
| M14 | Live Terrain Streaming | `PlanetStreamer.gd` mesh/collider orchestration and cancellation | M7-M9, M13 | DONE |
| M15 | Projectile Ring Buffer | `ProjectilePoolManager.gd` fixed 128-slot state, visuals, stepping, impacts, rebase | M10, M13 | DONE |
| M16 | Compute Dispatch Fallback | `ComputeChunkDispatcher.gd` Vulkan probe and std430 CPU parity | M7, M9 | DONE |
| M17 | Weapon & Radar System | `SpaceshipWeaponSystem.gd` firing and radial surface altimetry | M2, M15, M14 | DONE |
| M18 | Phase 3 Verification | `test_phase3_streaming_projectiles_headless.gd` Tiers 1-5 and all-suite regression | M14-M17 | DONE |

## Interface Contracts

### `TerrainMeshBuilder` ↔ Compute Shader & Engine
- `TerrainMeshBuilder.gd`:
  - `const GRID: int = 34`
  - `const INTERIOR: int = 32`
  - `const VERTEX_COUNT: int = 1156`
  - `const INDEX_COUNT: int = 6534`
  - `const SKIRT_FRACTION: float = 0.05`
  - `const MAX_WORKERS: int = 4`: Pre-allocates 4 independent scratch buffer sets (`_vertices_pool`, `_normals_pool`, `_uvs_pool`, `_mesh_arrays_pool`, `_faces_pool`) for race-free multi-threaded generation.
  - `pack_push_constants(face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2, planet_radius: float, seed_val: int, freq: float, amp: float) -> PackedByteArray`:
    Returns pre-allocated 48-byte buffer directly without heap allocations, matching `planet_chunk.glsl` std430 layout (three `vec4`).
  - `fbm4(p: Vector3, seed_val: int) -> Vector4`:
    Strict GLSL parity with 4 octaves, seed step `1013904223` (`0x3c6ef35f`), initial `amp = 0.5`, `freq *= 2.02`, and unnormalized accumulation.
  - `build_mesh_cpu(face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2, planet_radius: float, seed_val: int, freq: float, amp: float, target_mesh: ArrayMesh = null, chunk_local: bool = true, slot_idx: int = 0, skip_mesh: bool = false) -> ArrayMesh`:
    Deterministic CPU generation with tangential warp, 4-octave 3D simplex FBM, and 5% skirt extrusion toward planet center. Uses `slot_idx` in `[0..3]`.
  - `get_collider_faces(slot_idx: int = 0) -> PackedVector3Array`: Returns pre-allocated triangle face buffer for worker `slot_idx`.
  - `build_collider_faces(face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2, planet_radius: float, seed_val: int, freq: float, amp: float, slot_idx: int = 0, chunk_local: bool = true) -> PackedVector3Array`: Bakes collision geometry into worker scratch buffer `slot_idx`.
  - `build_chunk_mesh(mesh: ArrayMesh, face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2, planet_radius: float, seed_val: int, freq: float, amp: float, slot_idx: int = 0) -> ArrayMesh`: Generates chunk mesh using worker scratch buffer `slot_idx`.

### `ColliderPoolManager` ↔ `PlanetManager` & `QuadtreeNode`
- `ColliderPoolManager.gd`:
  - Extends `Node3D`.
  - `const POOL_SIZE: int = 64`
  - `func acquire_collider(owner_node: RefCounted) -> int`: Returns slot `[0..63]` or `-1` if exhausted in O(1).
  - `func release_collider(collider_id: int) -> bool`: Releases slot in O(1), resets `bodies[collider_id].position = Vector3.ZERO`, and clears shape faces.
  - `func set_collider_origin(collider_id: int, chunk_origin: Vector3) -> void`: Sets chunk-local origin position of the collider `StaticBody3D` relative to `PlanetManager`.
  - `func get_collider_origin(collider_id: int) -> Vector3`: Returns current body position.
  - `func update_collider_faces(collider_id: int, faces: PackedVector3Array) -> void`: Updates `ConcavePolygonShape3D`.
  - `func has_available(count: int = 1) -> bool`: O(1) admission check.
  - `func verify_integrity() -> Dictionary`: Checks active + free == 64, zero duplicate entries.
  - `func clear() -> void`: Resets all slots and releases node references.
- `QuadtreeNode.gd`:
  - Leaf chunks at `lod_level >= max_lod - 1` acquire/release colliders.
  - In `split()`: Admission check `col_pool.has_available(needed)` prevents overruns.
  - In `merge()` / destroy: Colliders cleanly released back to pool.

### `ChunkTaskScheduler`
- `ChunkTaskScheduler.gd`:
  - Extends `Node`.
  - `const MAX_CONCURRENT_WORKERS: int = 4`
  - `const BUFFER_CAPACITY: int = 64`
  - `static func get_current_worker_index() -> int` and `func get_worker_index() -> int`: Returns caller worker thread index `[0..3]`.
  - `func submit_job(callable: Callable, args: Array = []) -> int`: Submits background job in O(1).
  - `func is_job_completed(job_id: int) -> bool`
  - `func get_job_result(job_id: int) -> Variant`
  - `func cancel_job(job_id: int, auto_reclaim: bool = false) -> bool`: Cancels queued/running job and optionally marks for automatic reclamation.
  - `func cancel_all_jobs() -> void`: Cancels all queued and running jobs with automatic slot reclamation.
  - `func reclaim_job(job_id: int) -> bool`: Reclaims completed or cancelled slot back to free stack.
  - `func reclaim_cancelled_jobs() -> int`: Reclaims all cancelled slots in ring buffer.
  - `func poll() -> void`: Processes completed jobs and reclaims completed/cancelled slots marked with `_auto_reclaim` on main thread with 0 heap allocations.
  - `func shutdown() -> void`: Terminates worker threads cleanly.

### `AtmosphereMath` & `SpaceshipController` (Gravity)
- `AtmosphereMath.gd`:
  - `static func calculate_gravity_acceleration(vessel_pos: Vector3, planet_pos: Vector3, planet_radius: float, surface_gravity: float = 9.81) -> Vector3`:
    Radial inverse-square gravity toward `planet_pos`:
    $$\vec{g}(\vec{r}) = -g_0 \left(\frac{R}{\max(r, R)}\right)^2 \frac{\vec{r}}{r}$$
    Returns `Vector3.ZERO` when $r < 10^{-6}$.
- `SpaceshipController.gd`:
  - `@export var enable_planetary_gravity: bool = false`
  - `@export var surface_gravity: float = 9.81`
  - `var _gravity_force: Vector3 = Vector3.ZERO`
  - In `_physics_process`: Adds `_gravity_force` to `_net_force` with zero heap allocations.
  - In `rebase_origin(offset)`: Conserves orbital freefall velocity ($\Delta v < 10^{-4}$).

### `PlanetStreamer` ↔ Quadtree, Mesh, and Collider Pools
- `PlanetStreamer.gd`:
  - Extends `Node3D`; `const VISUAL_POOL_SIZE: int = 256`, `const JOB_CAPACITY: int = 64`.
  - `setup(planet: Node, scheduler: Node = null, immediate: bool = false) -> void`: Binds the planet pools and scheduler; immediate mode builds deterministically on the main thread.
  - `update_streamer(camera_pos: Vector3) -> void`: Drains prior jobs before `PlanetManager.update_camera()`, then reconciles every leaf with its pre-allocated visual and collider slot.
  - `visuals`, `mesh_owners`, `mesh_state`, `mesh_loaded`, `mesh_seen`, and `job_state` are allocated at startup; `mesh_state`/`job_state` use flat packed arrays.
  - Asynchronous work calls `ChunkTaskScheduler.get_current_worker_index()` and uses that worker's `TerrainMeshBuilder` scratch slot.
  - Split/merge resets hidden visuals, clears pooled mesh surfaces, cancels pending jobs, and returns staging slots without orphan resources.
  - `get_active_visual_count() -> int`, `get_orphan_mesh_count() -> int`, `destroy() -> void`.

### `ProjectilePoolManager`
- `ProjectilePoolManager.gd`:
  - Extends `Node3D`; `const POOL_SIZE: int = 128`.
  - Fixed state: `positions`, `velocities`, `lifetimes`, `is_in_use`, `free_indices`, 128 pooled `Node3D` markers, and one `PhysicsRayQueryParameters3D`.
  - `spawn_projectile(origin: Vector3, velocity: Vector3, lifetime: float = 5.0) -> int`: O(1), returns `[0..127]` or `-1` when exhausted.
  - `release_projectile(projectile_id: int) -> bool`: O(1) release; invalid/double release returns `false`.
  - `step_projectiles(delta, space_state = null, planet_center = Vector3.ZERO, planet_radius = 100_000.0, surface_gravity = 0.0) -> int`: Reuses scratch vectors/query, applies optional radial gravity, detects terrain impacts, and returns the impact count.
  - `rebase_origin(offset: Vector3) -> void`: Subtracts `offset` from active positions without changing velocities or lifetimes.
  - `verify_integrity() -> Dictionary`, `clear() -> void`.

### `ComputeChunkDispatcher` ↔ `planet_chunk.glsl`
- `ComputeChunkDispatcher.gd`:
  - Extends `RefCounted`; constants `WORKGROUP_X = 5`, `WORKGROUP_Y = 5`, `WORKGROUP_Z = 1`, `VERTEX_STRIDE_BYTES = 32`, `STORAGE_BUFFER_SIZE_BYTES = 36_992`, `VERTEX_COUNT = 1_156`.
  - `dispatch_chunk(...) -> ArrayMesh`: Uses a local `RenderingDevice` when available, otherwise deterministic `TerrainMeshBuilder.build_mesh_cpu()` fallback.
  - `pack_std430_vertex_buffer(slot_idx: int = 0) -> PackedByteArray`: Emits 1,156 `vec4 position_and_uv_x` + `vec4 normal_and_uv_y` records; returns a defensive duplicate.
  - `unpack_std430_vertex_buffer(raw_bytes: PackedByteArray, slot_idx: int = 0) -> bool`: Requires exactly 36,992 bytes and exposes packed/unpacked parity buffers.
  - `get_dispatch_group_count() -> Vector3i`, `get_invocation_count() -> int`, `get_effective_backend() -> String`, `shutdown() -> void`.

### `SpaceshipWeaponSystem`
- `SpaceshipWeaponSystem.gd`:
  - Extends `Node3D`; links `ship`, `projectile_pool`, `planet_manager`, and `terrain_collision_mask`.
  - `fire_projectile(muzzle_local_offset = Vector3(0, 0, -2), muzzle_speed = 800.0, lifetime = 5.0) -> int`: Uses the ship transform and `linear_velocity + forward * muzzle_speed`.
  - `measure_radar_altitude(space_state, max_range = 5000.0) -> float`: One reused radial query toward the planet center; returns the exact surface distance or `max_range` when no terrain is hit.
  - `get_radar_query() -> PhysicsRayQueryParameters3D`.

## Code Layout
- `TerrainMeshBuilder.gd`: Root project folder (<= 250 lines).
- `ColliderPoolManager.gd`: Root project folder (<= 250 lines).
- `ChunkTaskScheduler.gd`: Root project folder (<= 250 lines).
- `FloatingOrigin.gd`: Root project folder (<= 250 lines).
- `SpaceshipController.gd`: Root project folder (<= 250 lines).
- `AtmosphereMath.gd`: Root project folder (<= 250 lines).
- `PlanetManager.gd`: Root project folder (<= 250 lines).
- `PlanetMath.gd`: Root project folder (<= 250 lines).
- `QuadtreeNode.gd`: Root project folder (<= 250 lines).
- `ChunkPoolManager.gd`: Root project folder (<= 250 lines).
- `PlanetStreamer.gd`: Root project folder (250 lines).
- `ProjectilePoolManager.gd`: Root project folder (158 lines).
- `ComputeChunkDispatcher.gd`: Root project folder (209 lines).
- `SpaceshipWeaponSystem.gd`: Root project folder (72 lines).
- `planet_chunk.glsl`: Root project folder (Compute shader).
- Headless Test Runners:
  - `test_phase2_terrain_gravity_headless.gd`: Phase 2 automated test suite (Tiers 1-5).
  - `test_floating_origin_headless.gd`: Phase 1 E2E verification test suite.
  - `test_quadtree_headless.gd`: Quadtree pool stress test.
  - `test_adversarial_challenger2.gd`: Adversarial verification harness.
  - `test_adversarial_edge_cases.gd`: In-tree scene-tree physics and edge-case harness.
  - `test_adversarial_empirical.gd`: Continuous flight and hypersonic velocity harness.
  - `test_adversarial_m13_challenger1.gd`: Challenger 1 empirical concurrency, GLSL parity, and slot reclamation harness.
  - `test_adversarial_m13_challenger2.gd`: Challenger 2 empirical collider churn, push constants memory delta, and FBM parity harness.
  - `test_adversarial_m13_reviewer2.gd`: Reviewer 2 worker slot boundary clamping, auto-reclaim, and collider double release harness.
  - `test_phase3_streaming_projectiles_headless.gd`: Phase 3 streaming, projectile, compute, radar, memory, and regression suite (Tiers 1-5).
