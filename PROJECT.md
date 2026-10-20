# Project: Cryovanta Protocol - Floating Origin & 6-DOF Spaceship Physics

## Architecture
Cryovanta Protocol is a 64-bit precision procedural space simulation targeting high-performance mobile Vulkan 1.4 rendering (Godot 4.7).
The architecture decouples planetary terrain generation from local physics via coordinate rebasing:
- **Terrain Quadtree System**: `PlanetManager.gd`, `QuadtreeNode.gd`, `ChunkPoolManager.gd`, and compute shaders generate continuous spherical terrain.
- **Floating Origin System**: `FloatingOrigin.gd` monitors the player vessel. When $\|\vec{x}_{\text{player}}\| > 2000.0\text{ m}$, it subtracts the offset from player, registered entities, and the planet center offset, preserving topological and visual quadtree continuity without physics velocity spikes ($\Delta v < 10^{-4}$).
- **6-DOF Flight & Atmospheric Drag**: `SpaceshipController.gd` extends `RigidBody3D` with 6 degrees of freedom (surge, sway, heave, pitch, yaw, roll) with zero per-frame heap allocations.
- **Pure Static Math Libraries**: `AtmosphereMath.gd` encapsulates barometric density and aerodynamic quadratic drag ($F_d = -0.5 \cdot \rho(h) \cdot C_d \cdot A \cdot |v| \cdot \vec{v}$) with strict zero vacuum drag.
- **Automated Verification**: `test_floating_origin_headless.gd` executes headless validation across all tiers.

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

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Floating Origin System | `FloatingOrigin.gd`, update `PlanetManager.gd` | None | DONE |
| M2 | 6-DOF Spaceship Controller | `SpaceshipController.gd` (RigidBody3D, zero allocations) | None | DONE |
| M3 | Dynamic Atmospheric Drag | `AtmosphereMath.gd` and integration into `SpaceshipController.gd` | M2 | DONE |
| M4 | Headless E2E Test Suite | `test_floating_origin_headless.gd` (Tiers 1-4) | M1, M2, M3 | DONE |
| M5 | Final Verification & Hardening | Adversarial tests (Tier 5), Reviewer & Auditor gates | M1, M2, M3, M4 | DONE |

## Interface Contracts

### `FloatingOrigin` ↔ `PlanetManager`
- `PlanetManager.gd`:
  - `var planet_center_offset: Vector3 = Vector3.ZERO`
  - `func rebase_origin(offset: Vector3) -> void`: Subtracts `offset` from `planet_center_offset`.
  - In `update_camera(camera_pos: Vector3)`: Evaluates quadtree LOD using relative camera vector `camera_pos - planet_center_offset`.
- `FloatingOrigin.gd`:
  - Properties: `rebase_threshold: float = 2000.0`, `player_node: Node3D`, `planet_manager: Node`, `registered_entities: Array[Node3D]`.
  - Methods: `register_entity(entity: Node3D)`, `unregister_entity(entity: Node3D)`, `rebase(offset: Vector3)`.
  - Signal: `signal origin_rebased(offset: Vector3)`.

### `SpaceshipController` ↔ `AtmosphereMath`
- `AtmosphereMath.gd` (class_name `AtmosphereMath` or static functions):
  - `static func get_altitude(vessel_pos: Vector3, planet_pos: Vector3, planet_radius: float) -> float`
  - `static func get_air_density(altitude: float, atmosphere_ceiling: float, surface_density: float = 1.225) -> float`
  - `static func calculate_drag_force(velocity: Vector3, air_density: float, drag_coefficient: float = 0.5, cross_sectional_area: float = 10.0) -> Vector3`
- `SpaceshipController.gd`:
  - Extends `RigidBody3D`.
  - Direct input registers: `thrust_input: Vector3`, `torque_input: Vector3` (with `set_thrust_input`, `set_torque_input`).
  - Pre-allocated internal vectors for zero heap allocations.
  - Origin rebase handler: updates position, resets interpolation, preserves linear and angular velocity.

## Code Layout
- `FloatingOrigin.gd`: Root project folder (114 lines).
- `SpaceshipController.gd`: Root project folder (159 lines).
- `AtmosphereMath.gd`: Root project folder (59 lines).
- `PlanetManager.gd`: Root project folder (175 lines).
- `test_floating_origin_headless.gd`: Root project folder. Headless test runner (61 tests, 98 assertions).
