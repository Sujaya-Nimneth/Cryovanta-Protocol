# Changelog — Cryovanta Protocol

All notable changes across the phased stabilization and polish roadmap are documented below.

## [1.0.0-rc1] — 2026-11-20

### Phase 4 — Art Bible, Accessibility, Analytical Balance, Export Hardening & Release Docs (`testing-main` -> PR #5)
- Authored [design/art/art-bible.md](design/art/art-bible.md) codifying terrain elevation/slope palettes, procedural ship rig contracts (`10` children), and HUD color hierarchy.
- Authored [design/accessibility-requirements.md](design/accessibility-requirements.md); added idempotent gamepad joypad button/axis fallbacks in [FlightInputBindings.gd](FlightInputBindings.gd) and non-color `[!]` / `[!!]` alert severity prefixes in [CockpitHUDRenderer.gd](CockpitHUDRenderer.gd).
- Authored [design/balance/balance-check-sortie-20261120.md](design/balance/balance-check-sortie-20261120.md) auditing $\Delta v$ (`1,751.48 m/s`), wet-mass landing decel headroom, weapon heat lockouts, and solar/eclipse power draw.
- Hardened [export_presets.cfg](export_presets.cfg) (`exclude_filter`, `min_sdk="26"`, `target_sdk="35"`), removed stale October `build/CryovantaProtocol.apk*` & `build/runtime_preview.png*` artifacts, and authored [production/security/security-audit-20261120-full.md](production/security/security-audit-20261120-full.md).
- Authored release checklist (`production/releases/release-checklist-1.0.0.md`), patch notes (`docs/patch-notes/1.0.0.md`), and synchronized root docs to `43` production scripts and `36` manifest test suites.

### Phase 3 — Telemetry Instrumentation, Streaming Reclamation & Soak Verification (`06ba48e`, PR #4)
- Added microsecond per-subsystem step timing fields (`step_physics_usec`, `step_streamer_usec`, `step_director_hud_usec`, `step_total_usec`, `peak_step_usec`) across [SimulationTelemetry.gd](SimulationTelemetry.gd) and [PlanetarySimulation.gd](PlanetarySimulation.gd).
- Hardened `PlanetStreamer._cancel_slot_job()` to invoke `_release_retired_staging()` before retired slot capacity checks.
- Authored [ADR-0007](docs/architecture/adr-0007-terrain-backend-and-allocations.md), [control-manifest.md](docs/architecture/control-manifest.md), and [perf-profile-20261120.md](production/polish/perf-profile-20261120.md) (headless step average `153.3 µs` across 1,200 ticks; physical Adreno GPU profile explicitly `NOT ASSESSED`).
- Added a `2,400`-tick 10-cycle endurance soak test in [test_live_wiring_regression.gd](test_live_wiring_regression.gd) and authored [soak-test-20261120-30m.md](production/qa/soak-test-20261120-30m.md).

### Phase 2 — Playable Core Loop, Terrain Shading, HUD, Touch & Procedural Audio (`b1ef6d1`, PR #3)
- Authored GDD and UX specifications ([systems-index.md](design/gdd/systems-index.md), [core-sortie.md](design/gdd/core-sortie.md), [hud.md](design/ux/hud.md)).
- Enabled `cull_disabled` terrain rendering + signed elevation/slope contrast in [PlanetSurfaceMaterial.gd](PlanetSurfaceMaterial.gd); fixed CPU simplex `i2z` sector parity and preallocated 64-slot `_twx_pool` in [TerrainMeshBuilder.gd](TerrainMeshBuilder.gd); removed polar wind singularity ([PlanetaryWindModel.gd](PlanetaryWindModel.gd)); fixed bound radial apsides ([OrbitalMechanics.gd](OrbitalMechanics.gd)); synchronized `PhysicsServer3D` collider transforms on origin rebase ([ColliderPoolManager.gd](ColliderPoolManager.gd), [PlanetManager.gd](PlanetManager.gd)).
- Gated mission auto-wave spawning cleanly, added target evasion range/altitude leash, and scaled `MODE_SOFT_LAND` deceleration by vessel wet mass ([EncounterDirector.gd](EncounterDirector.gd), [FlightGuidanceSystem.gd](FlightGuidanceSystem.gd)).
- Added `pause_sortie` (`P`/`ESC`) and zero-leak 20-cycle `LiveSortieBootstrap.restart_sortie()`.
- Configured `canvas_items`/`expand` stretch ([project.godot](project.godot)), zero-overlap top touch action band `[344, vw - 214]`, numeric HUD readouts, `CAUTION - TRAFFIC` vs `CAUTION - TERRAIN`, `OVERHEAT` lockout indicator, numeric `SCORE`, and pause/end banners.
- Added zero-allocation procedural `AudioStreamGenerator` synthesis inside [PlanetaryEnvironment.gd](PlanetaryEnvironment.gd) (auto-muted under `--headless`).

### Phase 1 — Live-Wiring Fixes & ADRs (`ce90dcd`, PR #2)
- Resolved `BUG-0001..0005` and accepted `ADR-0001..0006`: single rendered-frame governor owner, 6-axis touch controls (`MobileTouchLayout.gd`), contact-gated touchdown (`0.15 s` persistence), coherent sortie rewind across vessel/pools/mission, lock-safe `ChunkTaskScheduler` teardown, and proper non-gravitational G-load + local roll visuals.

### Phase 0 — Baseline Truth & Test Harness (`6cb0ad4`, PR #1)
- Added nonrecursive `tests/manifest.txt` and `tools/run_tests.sh`, baseline project configuration (`project.yaml`), one-sortie brief (`design/game-brief.md`), bug records, and live wiring regression harness.
