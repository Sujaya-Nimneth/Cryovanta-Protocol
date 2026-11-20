# Cryovanta Protocol — Systems Index

**Document Tier:** Standard GDD Index (Brownfield Reconciliation)  
**Target Platform:** Godot 4.7.2 (`Vulkan Mobile`), Android ARM64 (`arm64-v8a`), 120 Hz physics (`8.333333 ms` target budget)  
**Code Root:** Root directory (`43` production `.gd` scripts, `1` GLSL compute shader, `1` scene, `36` nonrecursive test suites)

## 1. Architectural Invariants (`rules.md`)

All runtime modules enforce the following invariants unless explicitly superseded by an accepted ADR (`docs/architecture/`):

- **Zero steady-state allocations** inside `_process` and `_physics_process` (pre-allocated pools, `Packed*Array` buffers, and fixed-capacity ring buffers).
- **Root script & structural limits**: production `.gd` scripts reside in root `res://`, open with `class_name <PascalCase>` on line 1, and stay strictly `<= 250` lines (with tighter module ceilings verified by `test_phase14` and `test_adversarial_phaseE_challenger2`).
- **Concurrency cap**: at most 4 background worker threads via `ChunkTaskScheduler`.
- **Planetary projection & precision**: Cube-Sphere tangential warp `tan(uv * PI / 4.0)` with 5% skirts, `vec4`-aligned `std430` compute buffers (`32` bytes per `PlanetVertex`), and `2000.0 m` floating-origin rebasing.

---

## 2. Production Module Inventory (43 Scripts + Compute + Scene)

### 2.1 Core Simulation & Frame Orchestration

| Module | Class / Asset | Role & Ownership |
| :--- | :--- | :--- |
| [main.tscn](../../main.tscn) | `PlanetarySimulation` scene | Root entry scene instantiating `PlanetarySimulation`. |
| [PlanetarySimulation.gd](../../PlanetarySimulation.gd) | `PlanetarySimulation` | Top-level `Node` owning physics step orchestration, telemetry binding, live sortie startup, and HUD/visual updates. |
| [SimulationTelemetry.gd](../../SimulationTelemetry.gd) | `SimulationTelemetry` | Fixed-field telemetry bus aggregating kinematics, non-gravitational `g_load`, radar clearance, propellant, thermal, power, and gear registers. |
| [FloatingOrigin.gd](../../FloatingOrigin.gd) | `FloatingOrigin` | Translates active simulation coordinates when vessel distance exceeds the `2000.0 m` rebase threshold. |
| [FrameBudgetGovernor.gd](../../FrameBudgetGovernor.gd) | `FrameBudgetGovernor` | Adaptive quadtree budget controller targeting `8.333333 ms` (`120 FPS`). |
| [LiveSortieBootstrap.gd](../../LiveSortieBootstrap.gd) | `LiveSortieBootstrap` | Initializes a live sortie instance, binds flight recorder context (`ADR-0004`), and configures starting waypoints/sortie state. |

### 2.2 Planetary Terrain, Compute & Atmosphere

| Module | Class / Asset | Role & Ownership |
| :--- | :--- | :--- |
| [PlanetMath.gd](../../PlanetMath.gd) | `PlanetMath` | Pure static math for Cube-Sphere tangent warp, face transforms, and surface normalization. |
| [AtmosphereMath.gd](../../AtmosphereMath.gd) | `AtmosphereMath` | Pure static atmospheric density and aerodynamic drag calculations. |
| [OrbitalMechanics.gd](../../OrbitalMechanics.gd) | `OrbitalMechanics` | Keplerian trajectory prediction and orbital apsides/eccentricity math. |
| [QuadtreeNode.gd](../../QuadtreeNode.gd) | `QuadtreeNode` | Cube-face LOD quadtree subdivision logic driven by camera/vessel distance. |
| [TerrainMeshBuilder.gd](../../TerrainMeshBuilder.gd) | `TerrainMeshBuilder` | Deterministic CPU terrain mesh and noise vertex/index generator for chunks and collision meshes. |
| [ComputeChunkDispatcher.gd](../../ComputeChunkDispatcher.gd) | `ComputeChunkDispatcher` | RenderingDevice bridge for `planet_chunk.glsl` (`std430` 32-byte vertex layout) with deterministic CPU fallback. |
| [planet_chunk.glsl](../../planet_chunk.glsl) | GLSL Compute (`5,5,1`) | GPU terrain chunk vertex/normal compute shader targeting Vulkan Mobile. |
| [ChunkPoolManager.gd](../../ChunkPoolManager.gd) | `ChunkPoolManager` | Pre-allocated 256-slot `ArrayMesh` pool for O(1) chunk acquisition and recycling. |
| [ColliderPoolManager.gd](../../ColliderPoolManager.gd) | `ColliderPoolManager` | Fixed-capacity pool of terrain physics body/shape slots. |
| [ChunkTaskScheduler.gd](../../ChunkTaskScheduler.gd) | `ChunkTaskScheduler` | Bounded (`<= 4` workers) background chunk build queue with coherent `_cancel_all_unlocked()` cancellation/shutdown (`ADR-0006`). |
| [PlanetManager.gd](../../PlanetManager.gd) | `PlanetManager` | Manages the 6 cube-face quadtrees, chunk pool, collider pool, and terrain surface material binding. |
| [PlanetStreamer.gd](../../PlanetStreamer.gd) | `PlanetStreamer` | Streams background chunk builds into active meshes and manages staging slot reclamation. |
| [PlanetSurfaceMaterial.gd](../../PlanetSurfaceMaterial.gd) | `PlanetSurfaceMaterial` | Spatial shader material shading terrain by radial elevation and slope (`lowland_color`, `slope_color`, `highland_ice_color`). |
| [PlanetaryEnvironment.gd](../../PlanetaryEnvironment.gd) | `PlanetaryEnvironment` | Altitude-driven directional sun, ambient energy, sky multiplier, and exponential fog controller. |
| [PlanetaryWindModel.gd](../../PlanetaryWindModel.gd) | `PlanetaryWindModel` | Deterministic altitude/latitude planetary wind velocity field model. |

### 2.3 Vessel Flight, Propulsion, Thermal & Power

| Module | Class / Asset | Role & Ownership |
| :--- | :--- | :--- |
| [FlightInputBindings.gd](../../FlightInputBindings.gd) | `FlightInputBindings` | Idempotent `InputMap` registration (`15` actions across 6-DOF thrust/torque, weapon fire, guidance cycling, and rewind). |
| [SpaceshipController.gd](../../SpaceshipController.gd) | `SpaceshipController` | `RigidBody3D` 6-DOF spacecraft controller applying manual thrust, atmospheric drag, wind, and autopilot outputs. |
| [FlightGuidanceSystem.gd](../../FlightGuidanceSystem.gd) | `FlightGuidanceSystem` | 9-mode SAS/autopilot controller (`MODE_MANUAL` through `MODE_WAYPOINT_INTERCEPT`). |
| [PropellantMassModel.gd](../../PropellantMassModel.gd) | `PropellantMassModel` | Fuel consumption, wet-mass updates, delta-v estimation, `fuel_depleted`, and `thrust_cutoff` enforcement. |
| [ShipPowerBusModel.gd](../../ShipPowerBusModel.gd) | `ShipPowerBusModel` | Solar irradiance vs battery draw model, tracking charge fraction and brownout states. |
| [ThermalStructuralModel.gd](../../ThermalStructuralModel.gd) | `ThermalStructuralModel` | Atmospheric entry heat flux accumulation, radiator cooling, `heat_shield_load`, and thermal hull damage. |
| [LandingGearModel.gd](../../LandingGearModel.gd) | `LandingGearModel` | Animated deployment (`deploy_progress >= 0.95`), `0.15 s` contact persistence for `weight_on_wheels`, gear compression, and hard-impact damage (`ADR-0003`). |
| [EntityVisualsBuilder.gd](../../EntityVisualsBuilder.gd) | `EntityVisualsBuilder` | Procedural 3D vessel rig (`10` visual children), cached plume refs, landing struts, hostile targets, projectiles, and impact burst visuals. |

### 2.4 Combat, Sensors, Mission & Rewind

| Module | Class / Asset | Role & Ownership |
| :--- | :--- | :--- |
| [SpaceshipWeaponSystem.gd](../../SpaceshipWeaponSystem.gd) | `SpaceshipWeaponSystem` | Ballistic radar rangefinding (`last_radar_hit`), lead solution calculation, target lock selection, and projectile firing. |
| [WeaponHeatCapacitor.gd](../../WeaponHeatCapacitor.gd) | `WeaponHeatCapacitor` | Fixed heat budget capacitor with firing heat gain, passive dissipation, and overheat lockout hysteresis. |
| [ProjectilePoolManager.gd](../../ProjectilePoolManager.gd) | `ProjectilePoolManager` | Pre-allocated 128-slot projectile ring buffer with gravity integration and sweep collision checks. |
| [ImpactEffectPoolManager.gd](../../ImpactEffectPoolManager.gd) | `ImpactEffectPoolManager` | Pre-allocated 32-slot impact burst effect ring buffer. |
| [TargetPoolManager.gd](../../TargetPoolManager.gd) | `TargetPoolManager` | Fixed-capacity hostile target pool with free-stack index recycling and wave spawning. |
| [RadarOcclusionModel.gd](../../RadarOcclusionModel.gd) | `RadarOcclusionModel` | Planetary limb horizon occlusion and range-attenuated radar signal check. |
| [ProximityWarningSystem.gd](../../ProximityWarningSystem.gd) | `ProximityWarningSystem` | GPWS sink-rate/terrain clearance and closing-hostile proximity threat evaluator. |
| [WaypointRingBuffer.gd](../../WaypointRingBuffer.gd) | `WaypointRingBuffer` | Fixed-capacity navigation waypoint queue and distance/arrival tracker. |
| [FlightRecorderRingBuffer.gd](../../FlightRecorderRingBuffer.gd) | `FlightRecorderRingBuffer` | Pre-allocated telemetry + combat + mission snapshot ring buffer for coherent sortie rewind (`ADR-0004`). |
| [MissionScenarioRunner.gd](../../MissionScenarioRunner.gd) | `MissionScenarioRunner` | 3-stage sortie state machine (Recon, Interception, Precision Surface Touchdown). |
| [EncounterDirector.gd](../../EncounterDirector.gd) | `EncounterDirector` | Coordinates enemy evasion/AI, radar LOS, GPWS, thermal/power/fuel ticks, mission runner progression, and rewind binding. |

### 2.5 Cockpit HUD & Mobile Touch

| Module | Class / Asset | Role & Ownership |
| :--- | :--- | :--- |
| [CockpitHUD.gd](../../CockpitHUD.gd) | `CockpitHUD` | `CanvasLayer` storing mirrored telemetry registers, 64-step predicted trajectory, lock/waypoint state, and draw surface dispatch. |
| [CockpitHUDRenderer.gd](../../CockpitHUDRenderer.gd) | `CockpitHUDRenderer` | Immediate-mode vector and bar drawer for cockpit telemetry gauges, orbit path, reticles, warnings, and touch visuals. |
| [MobileTouchController.gd](../../MobileTouchController.gd) | `MobileTouchController` | 6-axis touch dual-stick, heave, roll, and discrete action state container. |
| [MobileTouchLayout.gd](../../MobileTouchLayout.gd) | `MobileTouchLayout` | Pure layout geometry, stick/heave/roll/action rect helpers, and touch-to-simulation action consumption (`ADR-0001`). |
| [MobileTouchOverlay.gd](../../MobileTouchOverlay.gd) | `MobileTouchOverlay` | Full-screen touch input router processing drag/tap events into `MobileTouchController` across portrait/landscape viewports. |

---

## 3. Cross-Reference Index

- **Project Charter & Brief:** [design/game-brief.md](../game-brief.md)
- **Core Sortie Design:** [design/gdd/core-sortie.md](core-sortie.md)
- **Cockpit HUD & Touch UX:** [design/ux/hud.md](../../design/ux/hud.md)
- **Architecture Decisions:** [docs/architecture/adr-0001..0006.md](../../docs/architecture/)
- **Implementation Plan:** [docs/implementation-plan.md](../../docs/implementation-plan.md)
