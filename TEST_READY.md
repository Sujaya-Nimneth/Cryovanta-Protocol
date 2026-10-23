# TEST_READY: Cryovanta Protocol Automated Verification Suites

## Phase 7 Readiness
Phase 7 is verified headlessly on Godot Engine v4.7.2.stable.official.ed1daf0bf. The hardened Phase 7 suite passes at **163 / 163 assertions**, and its complete Phase 1-6 regression gate passes across **19 suites** with exit code 0.

| Phase 7 Suite | Assertions | Failures | Exit Code | Verification Domain |
| :--- | ---: | ---: | ---: | :--- |
| `test_phase7_thermal_governor_encounters_headless.gd` | 163 | 0 | 0 | Vacuum cooling, calibrated hypersonic overheat/ablation, over-G damage, adaptive 120 FPS governor and quadtree topology response, deterministic orbital ring spawns, wave replacement and lock acquisition, HUD/telemetry sync, 1,000-tick memory stability, 28 production class-name/line checks, 19 prior suites |

## Test Execution Overview
All 20 automated test suites execute headlessly on Godot Engine v4.7.2.stable.official.ed1daf0bf with **exit code 0** and **0 failures**. The Phase 7 suite passes at **163 / 163 assertions**, including its 19-suite Phase 1-6 regression gate.

| Test Suite Script | Assertions / Steps | Failures | Exit Code | Verification Domain | Result |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `test_phase2_terrain_gravity_headless.gd` | 1,415 assertions | 0 | 0 | 34x34 skirted mesh, 48-byte std430 push constants, 4-worker scratch buffers, GLSL FBM parity, 64-slot collider pool, origin alignment, 4-worker scheduler, slot reclamation, radial gravity math, full Phase 1 regression | **PASS** |
| `test_adversarial_m13_challenger1.gd` | 2,365 assertions | 0 | 0 | 4-thread concurrency stress, burst cancellation & auto-reclaim, GLSL FBM constants & hash/grad parity, collider saturation | **PASS** |
| `test_adversarial_m13_challenger2.gd` | 8,066 assertions | 0 | 0 | ColliderPoolManager 5,000 churn cycles & origin alignment, push constants & scheduler poll zero memory delta, GLSL parity & concurrency | **PASS** |
| `test_adversarial_m13_reviewer2.gd` | 135 assertions | 0 | 0 | TerrainMeshBuilder slot index boundary clamping, scheduler cancellation edge cases & auto-reclaim, collider double release safety | **PASS** |
| `test_floating_origin_headless.gd` | 61 tests, 98 assertions | 0 | 0 | E2E origin rebasing, 6-DOF physics, atmospheric drag, line counts | **PASS** |
| `test_quadtree_headless.gd` | 1,000 steps, 0 orphans/leaks | 0 | 0 | Quadtree LOD subdivision, ring buffer mesh pooling | **PASS** |
| `test_adversarial_challenger2.gd` | 1,348 assertions | 0 | 0 | Adversarial topology, multi-ship rebase, deep LOD continuity | **PASS** |
| `test_adversarial_edge_cases.gd` | 44 assertions | 0 | 0 | In-tree SceneTree PhysicsServer3D synchronization & edge cases | **PASS** |
| `test_adversarial_empirical.gd` | 55 assertions | 0 | 0 | Sustained 1,000-frame rebases, hypersonic velocity, memory profiling | **PASS** |
| `test_adversarial_hardening.gd` | 3,032 assertions | 0 | 0 | Quadtree, pooling, scheduler, and origin hardening | **PASS** |
| `test_adversarial_challenger_hardening.gd` | 120 assertions | 0 | 0 | Adversarial pool and continuity checks | **PASS** |
| `test_adversarial_m10_reviewer2.gd` | 396 assertions | 0 | 0 | Gravity and flight reviewer regressions | **PASS** |
| `test_adversarial_m12_challenger.gd` | 1,993 assertions | 0 | 0 | Deep LOD, collider, and scheduler stress | **PASS** |
| `test_adversarial_m12_challenger2.gd` | 479 assertions | 0 | 0 | Cross-system Phase 2 adversarial checks | **PASS** |
| `test_adversarial_m8_reviewer2.gd` | 1,677 assertions | 0 | 0 | Collider pool and quadtree reviewer checks | **PASS** |
| `test_phase3_streaming_projectiles_headless.gd` | 2,626 assertions | 0 | 0 | 256-slot streaming, 30-frame async convergence, rebase alignment, 128-slot projectiles, std430 compute fallback, weapon/radar, memory and all-suite regression | **PASS** |
| `test_phase4_simulation_autopilot_headless.gd` | 415 assertions | 0 | 0 | Unified simulation, collision isolation, 6-DOF guidance, shared material, telemetry, HUD/environment integration, memory, class/line guardrails, and all-suite regression | **PASS** |
| `test_phase5_orbital_hud_environment_headless.gd` | 268 assertions | 0 | 0 | Keplerian mechanics, zero-tangent fallback, 64-point Velocity-Verlet prediction, manual-input preservation, prograde/circularization guidance, environment transition, input/HUD rebase, memory, 25-script guardrail, and 17-suite regression gate | **PASS** |
| `test_phase6_targets_combat_mobile_headless.gd` | 362 assertions | 0 | 0 | Target/impact pools, same-frame transform sync, projectile damage/effects, exact lead lock, dual HUD reticles, lock refresh, dual-stick input, telemetry, memory, 25-script guardrail, and 18-suite regression gate | **PASS** |
| `test_phase7_thermal_governor_encounters_headless.gd` | 163 assertions | 0 | 0 | Thermal/structural integrity, 120 FPS governor, quadtree topology response, deterministic encounter waves, HUD/telemetry sync, 1,000-tick memory, 28-script guardrail, and 19-suite regression gate | **PASS** |
| **Total Test Coverage** | **> 26,000 tests & assertions across 20 suites** | **0** | **0** | **Comprehensive Phase 1-7 Integration & Hardening** | **100% PASS** |

---

## Feature Inventory & Test Coverage Matrix

| # | Feature | Requirement Source | Test Suites Covering | Assertions / Tests | Status |
|---|---------|-------------------|----------------------|:------------------:|:------:|
| **F1** | Floating Origin Rebase Trigger | ORIGINAL_REQUEST R1 | `test_floating_origin_headless.gd`, `test_adversarial_empirical.gd` | 15 | **PASS** |
| **F2** | Planet Center Offset Interface | ORIGINAL_REQUEST R1 | `test_floating_origin_headless.gd`, `test_adversarial_challenger2.gd` | 14 | **PASS** |
| **F3** | World Entity & Camera Rebasing | ORIGINAL_REQUEST R1 | `test_floating_origin_headless.gd`, `test_adversarial_challenger2.gd` | 16 | **PASS** |
| **F4** | Zero Velocity Spike Continuity | ORIGINAL_REQUEST R1, R4 | All 6 test suites | > 500 | **PASS** |
| **F5** | 6-DOF Flight Controls | ORIGINAL_REQUEST R2 | `test_floating_origin_headless.gd`, `test_adversarial_challenger2.gd` | 24 | **PASS** |
| **F6** | Zero Runtime Heap Allocations | rules.md §1, R2 | `test_floating_origin_headless.gd`, `test_adversarial_edge_cases.gd`, `test_adversarial_empirical.gd`, `test_phase2_terrain_gravity_headless.gd` | > 100 | **PASS** |
| **F7** | Vacuum Boundary Drag Zeroing | ORIGINAL_REQUEST R3 | `test_floating_origin_headless.gd`, `test_adversarial_edge_cases.gd` | 12 | **PASS** |
| **F8** | Continuous Barometric Drag Profile | ORIGINAL_REQUEST R3 | `test_floating_origin_headless.gd`, `test_adversarial_edge_cases.gd` | 14 | **PASS** |
| **F9** | Script Line Count Guardrails | rules.md §3, R4 | `test_floating_origin_headless.gd`, `test_phase2_terrain_gravity_headless.gd` (Tier 5) | 15 | **PASS** |
| **F10** | Frequent Atomic Git Commits | ORIGINAL_REQUEST R5 | `test_floating_origin_headless.gd` (F10.1 - F10.5) | 5 | **PASS** |
| **F11** | Headless Automated Test Suite | ORIGINAL_REQUEST R4 | `test_floating_origin_headless.gd` (Tiers 1-4) | 98 | **PASS** |
| **F12** | Zero-Allocation Quadtree Math | Follow-up R1 | `test_quadtree_headless.gd`, `test_adversarial_challenger2.gd` | 1,000 steps + 1,348 assertions | **PASS** |
| **F13** | 64-Bit Sector Coordinate Tracking | Follow-up R2 | `test_floating_origin_headless.gd`, `test_adversarial_challenger2.gd`, `test_adversarial_empirical.gd` | 1,050 rebase checks | **PASS** |
| **F14** | Hierarchy & Double-Rebase Guards | Follow-up R3 | `test_adversarial_challenger2.gd`, `test_adversarial_edge_cases.gd`, `test_adversarial_empirical.gd` | 65 assertions | **PASS** |
| **F15** | Mobile Feature Configuration | Follow-up R4 | `project.godot` config verification | 1 | **PASS** |
| **F16** | 48-Byte std430 Push Constants | Phase 2 Follow-up R1 | `test_phase2_terrain_gravity_headless.gd` (Tier 1) | 30 | **PASS** |
| **F17** | 34x34 Skirted Chunk Mesh | Phase 2 Follow-up R1 | `test_phase2_terrain_gravity_headless.gd` (Tier 1) | 45 | **PASS** |
| **F18** | Zero-Allocation Mesh Buffers | Phase 2 Follow-up R1 | `test_phase2_terrain_gravity_headless.gd` (Tier 1) | 15 | **PASS** |
| **F19** | 64-Slot Terrain Collider Pool | Phase 2 Follow-up R2 | `test_phase2_terrain_gravity_headless.gd` (Tier 2) | 120 | **PASS** |
| **F20** | Quadtree Collider Gating | Phase 2 Follow-up R2 | `test_phase2_terrain_gravity_headless.gd` (Tier 2) | 1,000 movements | **PASS** |
| **F21** | Max-4 Worker Task Scheduler | Phase 2 Follow-up R3 | `test_phase2_terrain_gravity_headless.gd` (Tier 3) | 50 | **PASS** |
| **F22** | Radial Inverse-Square Gravity Math | Phase 2 Follow-up R4 | `test_phase2_terrain_gravity_headless.gd` (Tier 4) | 40 | **PASS** |
| **F23** | Spaceship Planetary Gravity | Phase 2 Follow-up R4 | `test_phase2_terrain_gravity_headless.gd` (Tier 4) | 50 | **PASS** |
| **F24** | Automated Phase 2 Test Suite | Phase 2 Follow-up R5 | `test_phase2_terrain_gravity_headless.gd` (Tier 5) | 1,415 assertions | **PASS** |
| **F25** | Full System Integrity & Hardening | Phase 2 Follow-up R5 | `test_phase2_terrain_gravity_headless.gd` (Tier 5), all suites | > 14,500 assertions | **PASS** |
| **F26** | Thread-Safe Per-Worker Scratch Buffers | Phase 2 Hardening R1 | `test_phase2_terrain_gravity_headless.gd` (Tier 1.7), `test_adversarial_m13_challenger1.gd`, `test_adversarial_m13_challenger2.gd`, `test_adversarial_m13_reviewer2.gd` | > 100 concurrency checks | **PASS** |
| **F27** | Exact GLSL FBM Noise Parity | Phase 2 Hardening R1 | `test_phase2_terrain_gravity_headless.gd` (Tier 1.6), `test_adversarial_m13_challenger1.gd`, `test_adversarial_m13_challenger2.gd` | 100 sample points + hash/grad parity | **PASS** |
| **F28** | Automatic Cancelled Slot Reclamation | Phase 2 Hardening R2 | `test_phase2_terrain_gravity_headless.gd` (Tier 3.6), `test_adversarial_m13_challenger1.gd`, `test_adversarial_m13_reviewer2.gd` | 15 burst cycles + auto_reclaim checks | **PASS** |
| **F29** | Chunk Collider Origin Alignment & Reset | Phase 2 Hardening R3 | `test_phase2_terrain_gravity_headless.gd` (Tier 2.6), `test_adversarial_m13_challenger1.gd`, `test_adversarial_m13_challenger2.gd` | 5,000 churn cycles + saturation checks | **PASS** |
| **F30** | Live Quadtree Mesh & Collider Streaming | Phase 3 R1-R2 | `test_phase3_streaming_projectiles_headless.gd` (Tier 1 + Hardening) | 256-slot preallocation, non-blocking 30-frame convergence, stable-job cancellation isolation, floating-origin visual/collider alignment, merge cancellation, zero orphans | **PASS** |
| **F31** | 128-Slot Projectile Ring Buffer | Phase 3 R2 | `test_phase3_streaming_projectiles_headless.gd` (Tier 2) | O(1) exhaustion/reuse, zero-allocation stepping, raycast impact, 2,000 m rebase | **PASS** |
| **F32** | Compute Dispatcher CPU Fallback | Phase 3 R3 | `test_phase3_streaming_projectiles_headless.gd` (Tier 3) | `(5, 5, 1)`, 36,992-byte std430 parity, pre-allocated readback buffers, 1,156-vertex fallback | **PASS** |
| **F33** | Weapon & Radar System | Phase 3 R4 | `test_phase3_streaming_projectiles_headless.gd` (Tier 4) | Muzzle inheritance, rebase continuity, high-LOD radial altimetry, zero-allocation firing | **PASS** |
| **F34** | Phase 3 Regression Gate | Phase 3 R5 + Hardening R4 | `test_phase3_streaming_projectiles_headless.gd` (Tier 5) | 18 production `class_name` declarations, strict line limits (PlanetStreamer <= 240), steady-state memory, all 15 prior suites | **PASS** |
| **F35** | Unified Simulation & Main Scene | Phase 4 R1 | `test_phase4_simulation_autopilot_headless.gd` (Tier 1) | `main.tscn` wiring, layer-isolated ship collider, startup altitude, live radar/projectile exclusion, protected camera, synchronized rebase | **PASS** |
| **F36** | SAS, Hover & Soft Landing | Phase 4 R2 | `test_phase4_simulation_autopilot_headless.gd` (Tier 2) | >95% SAS spin reduction, radial-up, altitude hold, monotonic high/low-altitude soft landing | **PASS** |
| **F37** | Shared Cryo Material | Phase 4 R3 | `test_phase4_simulation_autopilot_headless.gd` (Tier 3) | 256 shared overrides and rebase-synchronized shader uniforms | **PASS** |
| **F38** | Zero-Allocation Telemetry | Phase 4 R4 | `test_phase4_simulation_autopilot_headless.gd` (Tier 4) | Flight decomposition, G-load, pool counts, origin sector, 1,000-tick static memory delta | **PASS** |
| **F39** | Phase 4 Regression Gate | Phase 4 R5 | `test_phase4_simulation_autopilot_headless.gd` (Tier 5) | 18 class names and line limits, all 16 Phase 1-3 suites | **PASS** |
| **F40** | Keplerian Orbital Mechanics | Phase 5 R1 | `test_phase5_orbital_hud_environment_headless.gd` (Tier 1) | Circular/escape speed, energy, eccentricity, apsides, zero-tangent circularization fallback, 64-point Velocity-Verlet prediction within 1 m, zero static memory growth | **PASS** |
| **F41** | Prograde & Circularization Guidance | Phase 5 R2 | `test_phase5_orbital_hud_environment_headless.gd` (Tier 2) | Prograde alignment/cutoff, elliptical burn `e > 0.15` to `e < 0.01`, delta-v convergence, thrust cutoff, 2,000 m rebase | **PASS** |
| **F42** | Orbital Telemetry Registers | Phase 5 R2 | `test_phase5_orbital_hud_environment_headless.gd` (Tier 4) | Circular/escape speed, eccentricity, apsides, specific orbital energy, HUD register synchronization | **PASS** |
| **F43** | Surface-to-Vacuum Environment | Phase 5 R3 | `test_phase5_orbital_hud_environment_headless.gd` (Tier 3) | Surface factor 1.0, monotonic decay, exact vacuum factor/fog at and above ceiling, sky/fog transition, zero static growth | **PASS** |
| **F44** | Zero-Allocation Cockpit HUD | Phase 5 R4 | `test_phase5_orbital_hud_environment_headless.gd` (Tier 4) | 64-point fixed buffer, telemetry copy, trajectory advancement, rebase shift, 1,000-tick static memory delta | **PASS** |
| **F45** | Live Cockpit Input Wiring | Phase 5 R4 | `test_phase5_orbital_hud_environment_headless.gd` (Tier 4) | All 14 actions idempotently registered; manual thrust survives `step_simulation()` and produces forward force | **PASS** |
| **F46** | Phase 5 Regression Gate | Phase 5 R5 | `test_phase5_orbital_hud_environment_headless.gd` (Tier 5) | 22 production `class_name` declarations, 250-line limits, all 17 Phase 1-4 suites | **PASS** |
| **F47** | 32-Slot Target Ring Buffer | Phase 6 R1 | `test_phase6_targets_combat_mobile_headless.gd` (Tier 1) | O(1) exhaustion/reuse, motion, damage auto-release, 2,000 m rebase, zero-growth stepping | **PASS** |
| **F48** | 32-Slot Impact Ring Buffer | Phase 6 R2 | `test_phase6_targets_combat_mobile_headless.gd` (Tier 1) | O(1) exhaustion/reuse, expanding decay, auto-release, rebase, zero-growth stepping | **PASS** |
| **F49** | Projectile Damage & Impact Bursts | Phase 6 R2 | `test_phase6_targets_combat_mobile_headless.gd` (Tier 2) | Layer 1/4 mask, 2x50 damage destruction, auto-release, automatic burst spawning | **PASS** |
| **F50** | Ballistic Lead & Target Lock | Phase 6 R3 | `test_phase6_targets_combat_mobile_headless.gd` (Tier 3) | Exact quadratic lead below 1 m, nearest target, destroyed-lock refresh, target box and lead reticle, HUD rebase shifts | **PASS** |
| **F51** | Android Virtual Dual-Stick | Phase 6 R4 | `test_phase6_targets_combat_mobile_headless.gd` (Tier 4) | Radial deadzone, scalar filtering, 6-DOF mapping, manual simulation step, telemetry | **PASS** |
| **F52** | Phase 6 Regression Gate | Phase 6 R5 | `test_phase6_targets_combat_mobile_headless.gd` (Tier 5) | 25 production `class_name` declarations, 250-line limits, all 18 Phase 1-5 suites | **PASS** |
| **F53** | Atmospheric Thermal & Structural Integrity | Phase 7 R1 | `test_phase7_thermal_governor_encounters_headless.gd` (Tier 1) | Vacuum zero heating, calibrated hypersonic overheat, shield load, hull ablation, over-G damage, reset semantics | **PASS** |
| **F54** | Adaptive 120 FPS Frame-Budget Governor | Phase 7 R2 | `test_phase7_thermal_governor_encounters_headless.gd` (Tier 2) | 8.333 ms target, EMA sampling, streak hysteresis, 1.0-4.0 split-scale bounds, live quadtree topology response, nominal-step invariance | **PASS** |
| **F55** | Deterministic Orbital Encounter Spawner | Phase 7 R3 | `test_phase7_thermal_governor_encounters_headless.gd` (Tier 3) | Local-plane ring placement, tangential velocity, layer-4 targets, fixed-pool saturation, auto-spawn lock, wave turnover, disabled default | **PASS** |
| **F56** | Phase 7 Regression Gate | Phase 7 R4-R5 | `test_phase7_thermal_governor_encounters_headless.gd` (Tiers 4-5) | Telemetry/HUD mirroring, 1,000-tick zero growth, 28 production `class_name` declarations, 250-line limits, all 19 Phase 1-6 suites | **PASS** |

---

## Detailed Production Script Line Counts (rules.md §3 <= 250 Lines)

| Script File | Verified Line Count | Headroom to 250 Limit | Status |
| :--- | :---: | :---: | :---: |
| `AtmosphereMath.gd` | 88 lines | 162 lines | **COMPLIANT** |
| `SpaceshipController.gd` | 203 lines | 47 lines | **COMPLIANT** |
| `FloatingOrigin.gd` | 145 lines | 105 lines | **COMPLIANT** |
| `PlanetManager.gd` | 242 lines | 8 lines | **COMPLIANT** |
| `PlanetMath.gd` | 78 lines | 172 lines | **COMPLIANT** |
| `QuadtreeNode.gd` | 208 lines | 42 lines | **COMPLIANT** |
| `ChunkPoolManager.gd` | 111 lines | 139 lines | **COMPLIANT** |
| `ColliderPoolManager.gd` | 169 lines | 81 lines | **COMPLIANT** |
| `ChunkTaskScheduler.gd` | 248 lines | 2 lines | **COMPLIANT** |
| `TerrainMeshBuilder.gd` | 225 lines | 25 lines | **COMPLIANT** |
| `PlanetStreamer.gd` | 240 lines | 10 lines | **COMPLIANT** |
| `ProjectilePoolManager.gd` | 170 lines | 80 lines | **COMPLIANT** |
| `ComputeChunkDispatcher.gd` | 214 lines | 36 lines | **COMPLIANT** |
| `SpaceshipWeaponSystem.gd` | 140 lines | 110 lines | **COMPLIANT** |
| `PlanetarySimulation.gd` | 248 lines | 2 lines | **COMPLIANT** |
| `FlightGuidanceSystem.gd` | 214 lines | 36 lines | **COMPLIANT** |
| `PlanetSurfaceMaterial.gd` | 90 lines | 160 lines | **COMPLIANT** |
| `SimulationTelemetry.gd` | 98 lines | 152 lines | **COMPLIANT** |
| `OrbitalMechanics.gd` | 129 lines | 121 lines | **COMPLIANT** |
| `PlanetaryEnvironment.gd` | 80 lines | 170 lines | **COMPLIANT** |
| `CockpitHUD.gd` | 205 lines | 45 lines | **COMPLIANT** |
| `FlightInputBindings.gd` | 38 lines | 212 lines | **COMPLIANT** |
| `TargetPoolManager.gd` | 206 lines | 44 lines | **COMPLIANT** |
| `ImpactEffectPoolManager.gd` | 128 lines | 122 lines | **COMPLIANT** |
| `MobileTouchController.gd` | 54 lines | 196 lines | **COMPLIANT** |
| `ThermalStructuralModel.gd` | 61 lines | 189 lines | **COMPLIANT** |
| `FrameBudgetGovernor.gd` | 42 lines | 208 lines | **COMPLIANT** |
| `EncounterDirector.gd` | 74 lines | 176 lines | **COMPLIANT** |
| **Total Production Lines** | **4,148 lines** | **2,852 lines total headroom** | **100% COMPLIANT** |

*Note: Headless test suites (`test_phase2_terrain_gravity_headless.gd`, `test_phase3_streaming_projectiles_headless.gd`, `test_phase4_simulation_autopilot_headless.gd`, `test_phase5_orbital_hud_environment_headless.gd`, `test_phase6_targets_combat_mobile_headless.gd`, `test_phase7_thermal_governor_encounters_headless.gd`, `test_floating_origin_headless.gd`, `test_quadtree_headless.gd`, `test_adversarial_*.gd`) are standalone verification harnesses, not production runtime scripts.*

---

## Verification Execution Commands

To execute and verify all 20 headless test suites:
```bash
godot --headless -s test_phase2_terrain_gravity_headless.gd
godot --headless -s test_adversarial_m13_challenger1.gd
godot --headless -s test_adversarial_m13_challenger2.gd
godot --headless -s test_adversarial_m13_reviewer2.gd
godot --headless -s test_floating_origin_headless.gd
godot --headless -s test_quadtree_headless.gd
godot --headless -s test_adversarial_challenger2.gd
godot --headless -s test_adversarial_edge_cases.gd
godot --headless -s test_adversarial_empirical.gd
godot --headless -s test_adversarial_hardening.gd
godot --headless -s test_adversarial_challenger_hardening.gd
godot --headless -s test_adversarial_m10_reviewer2.gd
godot --headless -s test_adversarial_m12_challenger.gd
godot --headless -s test_adversarial_m12_challenger2.gd
godot --headless -s test_adversarial_m8_reviewer2.gd
godot --headless -s test_phase3_streaming_projectiles_headless.gd
godot --headless -s test_phase4_simulation_autopilot_headless.gd
godot --headless -s test_phase5_orbital_hud_environment_headless.gd
godot --headless -s test_phase6_targets_combat_mobile_headless.gd
godot --headless -s test_phase7_thermal_governor_encounters_headless.gd
```

To verify production script line counts:
```bash
wc -l AtmosphereMath.gd ChunkPoolManager.gd ChunkTaskScheduler.gd CockpitHUD.gd ColliderPoolManager.gd ComputeChunkDispatcher.gd EncounterDirector.gd FlightGuidanceSystem.gd FlightInputBindings.gd FloatingOrigin.gd FrameBudgetGovernor.gd ImpactEffectPoolManager.gd MobileTouchController.gd OrbitalMechanics.gd PlanetManager.gd PlanetMath.gd PlanetStreamer.gd PlanetSurfaceMaterial.gd PlanetaryEnvironment.gd PlanetarySimulation.gd ProjectilePoolManager.gd QuadtreeNode.gd SimulationTelemetry.gd SpaceshipController.gd SpaceshipWeaponSystem.gd TargetPoolManager.gd TerrainMeshBuilder.gd ThermalStructuralModel.gd
```
