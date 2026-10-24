# Cryovanta Protocol

Cryovanta Protocol is a procedural planetary flight and combat simulation for
Godot 4.7, targeting Android ARM64 devices with the Vulkan Mobile renderer.
The reference device is Snapdragon 8 Elite Gen 5 with Adreno 840 graphics,
landscape 1920x1080 output, 120 Hz physics ticks, and a 120 FPS frame budget.

The project is designed around fixed-capacity pools and reusable registers. All
39 production GDScript files declare `class_name`, stay at or below 250 lines,
and keep allocation-sensitive simulation paths free of `new()`, `.duplicate()`,
and growing `Array` or `Dictionary` operations.

## Quick Start

Requirements:

- Godot 4.7 or newer, with the matching Android export templates installed.
- Android SDK and OpenJDK 17 for APK export.
- A Vulkan-capable Android device for hardware validation.

Run from the editor:

1. Open `project.godot`.
2. Press F6/F5 to launch `main.tscn`.
3. Use the desktop controls below, or deploy the Android APK to a touch device.

Run a headless test:

```bash
godot --headless -s test_phase14_release_export_touch_headless.gd
```

## Architecture

`main.tscn` instantiates `PlanetarySimulation`, the composition root. It creates
the planet, streamer, floating origin, ship, pools, weapon system, guidance,
environment, HUD, telemetry, and encounter director once. Each simulation tick
runs input and guidance, flight forces, origin rebasing, target and projectile
updates, terrain streaming, telemetry, environment, encounter systems, and HUD
refresh in that order.

The simulation uses a local-origin coordinate frame. World content is shifted
when the ship crosses 2,000 m, keeping render and physics coordinates small
while preserving linear velocity, angular velocity, and orbital continuity.

### Runtime and input

| Script | Responsibility |
| :--- | :--- |
| `PlanetarySimulation.gd` | Scene composition root, setup/teardown, and ordered simulation tick. |
| `FloatingOrigin.gd` | 2,000 m rebase trigger, hierarchy guard, and 64-bit sector/local coordinate bookkeeping. |
| `SpaceshipController.gd` | 6-DOF rigid-body flight, thrust/torque registers, drag, gravity, and rebase continuity. |
| `FlightInputBindings.gd` | Idempotent registration of the 14 desktop flight and combat actions. |
| `MobileTouchController.gd` | Radial-deadzoned virtual sticks mapped to ship thrust and torque. |
| `MobileTouchOverlay.gd` | Allocation-free multi-touch router for left/right sticks and top-band action taps. |

### Planet, terrain, and streaming

| Script | Responsibility |
| :--- | :--- |
| `PlanetManager.gd` | Planet state, six-face cube-sphere quadtree, LOD policy, gravity reference, and rebase. |
| `PlanetMath.gd` | Precomputed cube-face bases, tangential warp, and primitive bounds math. |
| `QuadtreeNode.gd` | Recursive LOD nodes, split/merge admission, and collider ownership. |
| `ChunkPoolManager.gd` | Fixed chunk and node pool storage. |
| `ColliderPoolManager.gd` | 64-slot `StaticBody3D` and `ConcavePolygonShape3D` collider pool. |
| `TerrainMeshBuilder.gd` | 34x34 skirted chunk mesh generation and 48-byte std430 push constants. |
| `ComputeChunkDispatcher.gd` | `(5, 5, 1)` compute dispatch, 36,992-byte vertex readback, and deterministic CPU fallback. |
| `PlanetStreamer.gd` | 256-slot visual reconciliation, asynchronous jobs, cancellation, and origin synchronization. |
| `PlanetSurfaceMaterial.gd` | One shared procedural terrain material with rebase-aware planet uniforms. |

### Flight, orbit, and combat

| Script | Responsibility |
| :--- | :--- |
| `AtmosphereMath.gd` | Barometric density, inverse-square radial gravity, and quadratic drag. |
| `OrbitalMechanics.gd` | Keplerian element helpers and fixed-buffer Velocity-Verlet prediction. |
| `FlightGuidanceSystem.gd` | Nine-mode 6-DOF guidance: manual, SAS, radial-up, retrograde, hover, soft landing, prograde, circularization, and waypoint intercept. |
| `SpaceshipWeaponSystem.gd` | Muzzle-relative firing, ballistic lead, target lock, heat gating, and radar altimetry. |
| `ProjectilePoolManager.gd` | 128-slot projectile ring with gravity, ray impacts, and rebase continuity. |
| `TargetPoolManager.gd` | 32-slot target pool with colliders, health, motion, and damage release. |
| `ImpactEffectPoolManager.gd` | 32-slot expanding impact-effect pool. |
| `WeaponHeatCapacitor.gd` | Fixed-state heat accumulation, cooldown, and overheat lockout. |

### Environment, health, and power

| Script | Responsibility |
| :--- | :--- |
| `PlanetaryEnvironment.gd` | Sun, sky, fog, and surface-to-vacuum lighting transitions. |
| `ThermalStructuralModel.gd` | Convective entry heating, cryogenic cooling, shield load, and hull ablation. |
| `PlanetaryWindModel.gd` | Altitude-banded wind, jetstream, and deterministic turbulence. |
| `ShipPowerBusModel.gd` | Solar generation, eclipse shadow, battery load, and brownout protection. |
| `LandingGearModel.gd` | Automatic gear actuator, drag interpolation, touchdown compression, and hard-landing damage. |
| `RadarOcclusionModel.gd` | Planet-horizon line of sight and range-attenuated target/waypoint signals. |

### Mission, telemetry, and operations

| Script | Responsibility |
| :--- | :--- |
| `EncounterDirector.gd` | Deterministic waves and coordinator for thermal, wind, power, gear, radar, mission, recorder, and scoring systems. |
| `WaypointRingBuffer.gd` | 16-slot waypoint and landing-beacon ring with sequential capture. |
| `FlightRecorderRingBuffer.gd` | 64-slot black-box flight snapshot ring with physics restore and rebase shift. |
| `MissionScenarioRunner.gd` | Three-stage recon, intercept, and soft-landing mission state machine. |
| `PropellantMassModel.gd` | Tsiolkovsky propellant flow, wet mass, delta-v, and depletion cutoff. |
| `ProximityWarningSystem.gd` | Terrain and target GPWS caution/pull-up threat evaluation. |
| `FrameBudgetGovernor.gd` | EMA-based 120 FPS budget control and adaptive quadtree split scale. |
| `SimulationTelemetry.gd` | O(1) flight, orbital, streaming, combat, power, gear, and LOS register sampling. |
| `CockpitHUD.gd` | Zero-allocation cockpit rendering, trajectory projection, reticles, alerts, and status bars. |

## Subsystem Summary

| Subsystem | Contract |
| :--- | :--- |
| Floating Origin | Rebase at 2,000 m while preserving velocities, hierarchy, sectors, pools, HUD, and orbital state. |
| Cube-Sphere Quadtree | Six cube faces with tangential warp and adaptive LOD; no topological seam stitching. |
| Mesh and Collider Pools | 256 pre-allocated terrain visuals and 64 pre-allocated terrain colliders. |
| Worker Scheduler | Maximum four workers over a fixed 64-job ring, with cancellation and automatic reclamation. |
| Compute and Fallback | std430 GPU contract with deterministic CPU mesh generation on unsupported headless environments. |
| Autopilot | Nine 6-DOF modes with gravity feed-forward and manual-input preservation. |
| Orbit Predictor | Keplerian orbital registers plus a fixed 64-point predicted trajectory. |
| Entry Thermal Model | Air-relative stagnation heating, shield load, cooling, and hull ablation. |
| Frame Governor | 8.333 ms target, EMA hysteresis, and bounded LOD split-scale control. |
| Propellant and Power | Variable wet mass, Tsiolkovsky delta-v, solar charging, eclipse drain, and weapon brownout. |
| GPWS and Radar LOS | Terrain/target threat warnings plus planetary-horizon occlusion and signal attenuation. |
| Black Box and Mission | 64-slot recorder restore and a deterministic three-stage recon/intercept/landing sortie. |

## Controls

### Desktop keyboard

| Input | Action |
| :--- | :--- |
| `W` / `S` | Forward / reverse thrust |
| `A` / `D` | Strafe left / right |
| `E` / `Q` | Vertical up / down |
| `I` / `K` | Pitch up / down |
| `J` / `L` | Yaw left / right |
| `U` / `O` | Roll left / right |
| `Space` | Fire weapon |
| `Tab` | Cycle guidance mode |

### Android touch

Touch below the top 20 percent of the screen:

| Gesture | Action |
| :--- | :--- |
| Left-half press and drag | Left stick: strafe and forward/reverse throttle |
| Right-half press and drag | Right stick: pitch and yaw |

Action taps in the top band:

| Gesture | Action |
| :--- | :--- |
| Top-right tap | Request weapon fire |
| Top-left tap | Request guidance-mode cycle |

The overlay accepts multi-touch by tracking independent left and right touch
indices. A drag is normalized by `joystick_radius` and clamped by the controller
deadzone. `MobileTouchOverlay` is a `RefCounted` event router: an input host
forwards `InputEventScreenTouch` and `InputEventScreenDrag` to
`handle_touch_point()` and `handle_drag_point()`, then consumes the latched
`fire_requested` and `cycle_mode_requested` flags. `reset()` clears both sticks,
touch ownership, and pending action requests.

## Android Export

`project.godot` configures landscape orientation, 1920x1080 reference viewport,
VSync, mouse-to-touch emulation, 120 physics ticks per second, the Mobile
renderer, and ETC2/ASTC VRAM compression. The renderer uses Vulkan on Android
and is validated against a Vulkan 1.4 / Adreno 840 target.

`export_presets.cfg` contains the `Android` preset:

- Package: `com.cryovanta.protocol`
- Display name: `Cryovanta Protocol`
- Version: `1.0.0`
- ABI: `arm64-v8a` only
- XR mode: disabled
- Gradle build: disabled
- Output: `build/CryovantaProtocol.apk`

### Editor

1. Install the Godot 4.7 Android export templates.
2. Configure Android SDK and OpenJDK 17 under Editor Settings > Export > Android.
3. Open Project > Export and select `Android`.
4. For a release APK, configure the release keystore and credentials.
5. Export to `build/CryovantaProtocol.apk`.
6. Install on a Vulkan-capable ARM64 device and verify landscape startup,
   two-touch sticks, mode cycling, weapon fire, and the 120 Hz physics cadence.

### Command line

```bash
mkdir -p build
godot --headless --path . --export-debug "Android" build/CryovantaProtocol.apk
```

For a signed release build:

```bash
mkdir -p build
godot --headless --path . --export-release "Android" build/CryovantaProtocol.apk
```

Debug export uses the local Android debug keystore. Release export requires the
keystore configured in the editor. The `build/`, `*.apk`, and `*.aab` patterns
are ignored by Git; `export_presets.cfg` remains tracked.

## Headless Verification

Refresh the global class cache after adding scripts, then run the final gate:

```bash
godot --headless --editor --quit --path .
godot --headless -s test_phase14_release_export_touch_headless.gd
```

The Phase 14 gate verifies project/export settings, overlay multi-touch routing,
1,000 ticks with no static-memory growth, all 39 production script guardrails,
and all 26 prior suites. To execute the complete 27-suite set directly:

```bash
set -e
for suite in test_*.gd; do
  godot --headless -s "$suite"
done
```

The full gate can take several minutes because release suites recursively run
their historical regression gates. The source of truth for assertion totals,
feature coverage, and production line counts is `TEST_READY.md`.

## Repository Map

```text
project.godot                 project and mobile renderer settings
export_presets.cfg            Android ARM64 APK preset
main.tscn                     playable simulation scene
*.gd                         39 production scripts and headless suites
planet_chunk.glsl             std430 chunk compute shader
rules.md                      architecture and memory guardrails
PROJECT.md                    detailed subsystem and interface contracts
TEST_INFRA.md                 test harness conventions
TEST_READY.md                 final release certification and coverage matrix
```
