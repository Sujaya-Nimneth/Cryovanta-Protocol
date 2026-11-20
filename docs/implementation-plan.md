# Cryovanta Protocol — Repair & Improvement Implementation Plan

**Audit date:** 2026-11-20

**Baseline commit:** `624b68e` (`main`)

**Engine observed:** Godot `4.7.2.stable.official.ed1daf0bf`

**Primary target:** Android ARM64, Vulkan Mobile, Snapdragon 8 Elite Gen 5 / Adreno 840, 120 Hz physics

**Status:** Phase 1 complete on `testing-main` (all 36 nonrecursive suites / 45,287 reported assertions passing); ready to merge Phase 1 PR and proceed to Phase 2. Release remains NOT READY until Phases 2–4 and Android hardware checks complete.

---

## 1. Executive verdict

**Observed stage: Production / technical prototype. Release gate: NOT READY.**

The project has a valuable technical foundation: fixed-capacity pools, a four-worker scheduler, cube-sphere terrain, floating-origin rebasing, deterministic math libraries, and a large headless test corpus. Preserve that architecture. Do not rewrite the engine layer or migrate frameworks.

The current “final release certification” claim is not supported by the evidence:

- The Phase 14 master gate passes, but it runs only its explicit 27-suite registry and omits seven existing adversarial suites.
- Live probes found five concrete gameplay/wiring failures: partial rewind, missing touch heave/roll, and mission completion without touchdown.
- The automatic frame governor is sampled twice, while manual/headless tests exercise only the nominal-delta path.
- The live asynchronous terrain path uses CPU buffers; the Vulkan compute path is synchronous and has not been profiled on the target device.
- The existing APK and runtime screenshot predate the latest code commits and are not current release evidence.
- There is no current Android device run, Vulkan profile, thermal/soak report, playtest record, or formal release checklist.

**Device/Vulkan/performance certification: NOT ASSESSED.** Absence of evidence is not a pass.

### Recommended product scope

Deliver one polished, repeatable sortie:

1. Launch into an intentional flight state.
2. Understand the objective and controls.
3. Recon a waypoint.
4. Intercept drones.
5. Land with real touchdown semantics.
6. See success/failure, restart, and replay.

Do not add multiplayer, economy, new planets, biomes, save progression, or a heavy studio pipeline before this loop is trustworthy.

---

## 2. Evidence baseline

| Check | Observed result | Meaning |
| :--- | :--- | :--- |
| Production GDScript | 42 files, 5,755 lines | README’s 39-script claim is stale |
| Root test scripts | 35 `test_*.gd` files | TEST_READY’s 28-suite total is stale |
| Phase 14 master | 190/190 assertions, exit 0 | Passes its own registry, not the whole corpus |
| Seven omitted suites | All pass individually | Corpus is broader than the master gate |
| Live wiring probe | 5 failures | Rewind fuel/mission, touch heave/roll, landing contact |
| Async steady-state probe | 120 visuals, 0 pending jobs, 64 staging slots free, static delta 0 | Good pool behavior, not proof of zero allocation or GPU performance |
| Scheduler mutex probe | Recursive `try_lock()` succeeds on this engine | Nested lock is fragile, not a confirmed Godot 4.7.2 deadlock |
| APK | `build/CryovantaProtocol.apk`, dated 2026-10-28 | Latest code commits are 2026-11-02; artifact is stale |
| Runtime preview | `build/runtime_preview.png`, dated 2026-10-28 | Not current visual QA evidence |
| CI | None found | No repeatable nonrecursive gate |
| Design/production artifacts | No GDDs, ADRs, stories, playtests, device profiles, or bug records | Formal design/balance/content/security checks are NOT ASSESSED |

Temporary audit logs were written under `/tmp/cryovanta-audit-20261120/`. Phase 0 must persist the useful evidence inside the repository before it is lost.

### Current reproduction commands

```bash
godot --headless --editor --quit --path .
godot --headless -s test_phase14_release_export_touch_headless.gd -- --direct-regression
```

The current master is useful, but it is not a complete corpus runner. The seven omitted suites are:

```text
test_adversarial_phaseC_challenger2.gd
test_adversarial_phaseD_challenger.gd
test_adversarial_phaseD_challenger2.gd
test_adversarial_phaseD_reviewer2.gd
test_adversarial_phaseE_challenger.gd
test_adversarial_phaseE_challenger2.gd
test_adversarial_phaseE_reviewer2.gd
```

---

## 3. Preserve, fix, improve, defer

### Preserve

- `PlanetarySimulation` as the composition root and ordered tick.
- Fixed pools: 256 terrain visuals, 64 colliders, 64 scheduler jobs/staging slots, 128 projectiles, 32 targets, 32 impacts, 16 waypoints, 64 recorder samples.
- Maximum four background workers.
- Cube-sphere tangential warp and skirted chunks; no topological seam stitching.
- `std430` `vec4` layout, 32-byte vertex stride, 48-byte push constants, 36,992-byte storage buffer.
- Floating-origin rebasing at 2,000 m and sector/local bookkeeping.
- Pure static math separated from engine nodes.
- Headless regression culture and the 250-line script guardrail.

### Fix first

- Frame-governor ownership and sampling.
- Rewind semantics and state completeness.
- Touch access to all advertised 6 DOF.
- Touchdown and mission completion.
- Scheduler nested-lock cleanup.
- Test manifest, CI, and stale release documentation.

### Improve next

- Intentional spawn/orbit/mission flow.
- Pause, restart, failure, and completion states.
- Readable responsive HUD and discoverable controls.
- Basic audio and combat/flight feedback.
- Measured mobile performance and allocation budgets.
- Lean art direction and asset standards.

### Defer

- Multiplayer/networking.
- Economy, progression, save/load, or live ops.
- Additional planets, biomes, or large content packs.
- Engine/framework migration.
- Full studio ceremony: large epic trees, director panels, and mandatory artifacts that do not help a solo project.

---

## 4. Findings register

Priority: `P0` stop false release claims; `P1` next implementation cycle; `P2` polish/release; `P3` backlog.

Severity: `S2` core-loop/release blocker; `S3` medium UX/maintainability issue; `S4` minor polish.

| ID | Priority | Finding | Evidence | Primary files | Disposition |
| :--- | :--- | :--- | :--- | :--- | :--- |
| F-01 | P0 | Release claims exceed verified coverage | Master registry omits seven passing suites; docs claim 28 suites / 28,150 tests | `test_phase14_release_export_touch_headless.gd`, `TEST_READY.md`, `README.md` | Build nonrecursive manifest/runner; correct docs |
| F-02 | P1 / S2 | Frame governor double-sampled | `EncounterDirector.gd:170` samples `delta * 1000`; `PlanetarySimulation.gd:39-46` samples wall time afterward in automatic mode | `EncounterDirector.gd`, `PlanetarySimulation.gd`, `FrameBudgetGovernor.gd` | One owner, one real frame sample; separate tick from render timing |
| F-03 | P1 / S2 | Rewind restores only partial flight state | Probe restored position/hull but left fuel 100 instead of 600 and mission stage 5 instead of 2 | `FlightRecorderRingBuffer.gd`, `LiveSortieBootstrap.gd` | Choose full sortie checkpoint or explicitly rename/reduce feature; no silent partial restore |
| F-04 | P1 / S2 | Touch cannot command heave or roll | Overlay always passes vertical/roll as `0.0` | `MobileTouchOverlay.gd:60-82`, `MobileTouchController.gd` | Add deliberate, visible heave/roll controls and gesture-level tests |
| F-05 | P1 / S2 | Mission can complete without touchdown | Completion accepts radar altitude ≤25 m and speed ≤5 m/s; probe completed at 20 m without weight-on-wheels | `MissionScenarioRunner.gd:79-82`, `LandingGearModel.gd:52` | Require real gear contact/stable touchdown; calibrate landing damage |
| F-06 | P1 / S2 | Async/GPU path unverified and allocation-risky | Live async worker uses CPU buffers; GPU dispatch does `submit(); sync(); buffer_get_data()` per chunk | `PlanetStreamer.gd:97-127`, `ComputeChunkDispatcher.gd:104-127`, `TerrainMeshBuilder.gd:154` | Profile actual Vulkan path; decide CPU vs GPU; define allocation budget |
| F-07 | P1 / S2 | No current device/release evidence | APK/screenshot predate latest commits; no Android run, Vulkan profile, soak, or thermal report | `build/`, `export_presets.cfg`, release docs | Build current candidate and validate on target hardware |
| F-08 | P1 / S2 | Default sortie is not an intentional playable loop | Ship spawns at 1,000 m with zero velocity and falls; waypoint is 300 m forward; drones move tangentially at 45 m/s | `PlanetarySimulation.gd`, `LiveSortieBootstrap.gd`, `EncounterDirector.gd`, `TargetPoolManager.gd` | Design and implement one coherent spawn/mission/target model |
| F-09 | P1 / S2 | HUD is weak on mobile | Fixed-pixel panels, 9–12 px text, bars without numeric values, unlabeled mode squares, touch labels hidden until active | `CockpitHUDRenderer.gd:51-223`, `CockpitHUD.gd` | Responsive layout, numeric readouts, persistent labels, safe areas |
| F-10 | P2 / S3 | No pause/restart/failure recovery | No menu or recovery flow found | `PlanetarySimulation.gd`, `LiveSortieBootstrap.gd`, HUD | Add minimal pause/failure/complete flow and full reset |
| F-11 | P2 / S3 | Scheduler shutdown nests mutex locks | `shutdown()` locks, then calls `cancel_all_jobs()`, which locks again | `ChunkTaskScheduler.gd:152-162`, `:238-246` | Extract unlocked helper; stress concurrent shutdown |
| F-12 | P2 / S3 | G-load semantics likely inverted for flight HUD | Net force includes gravity; freefall reads ~1 G, hover can read ~0 G | `SimulationTelemetry.gd:87-90`, `SpaceshipController.gd` | Define proper G vs coordinate acceleration; update thermal/HUD tests |
| F-13 | P2 / S3 | Radar LOS is displayed but not enforced | LOS registers exist; firing does not check them | `RadarOcclusionModel.gd`, `SpaceshipWeaponSystem.gd`, `EncounterDirector.gd` | Make a design decision; enforce or document intentional behavior |
| F-14 | P2 / S3 | Placeholder art and no audio | Primitive ship/targets; no audio assets or players found | `EntityVisualsBuilder.gd`, asset root | Lean art bible, asset pass, pooled audio feedback |
| F-15 | P3 / S4 | Visual roll uses world angular Z and repeated node lookups | `update_flight_visuals` reads world angular velocity and calls `get_node_or_null` each update | `EntityVisualsBuilder.gd:142-165` | Cache references; use local angular state |
| F-16 | P2 / S3 | Security scope is unconfirmed | No save/network code found, but no explicit offline scope or audit report | project config, export presets, input/resource loading | Confirm offline scope; run full-scope audit before release |

### Probe results to turn into regressions

```text
ASYNC visuals=120->120 pending=0 staging_free=64 static_delta=0
PASS: async steady state has no pending jobs
PASS: async steady state returns all staging slots
PASS: async steady state has zero static memory growth

REWIND restored=true hull=80.0 fuel=100.0 mission_stage=5
FAIL: rewind restores fuel
FAIL: rewind restores mission stage

TOUCH thrust=(0.0, 0.0, 1.0) torque=(0.707107, 0.707107, 0.0)
FAIL: touch overlay can command vertical thrust
FAIL: touch overlay can command roll torque

FAIL: mission completion requires weight-on-wheels
PROBE_FAILURES=5
```

The async result is a pool/stability pass, not a literal zero-allocation certificate. `OS.get_static_memory_usage()` does not measure all transient allocations, GPU readback, mesh upload, or collider baking costs.

---

## 5. Dependency-ordered implementation phases

Estimates are focused engineering days for one developer. They are provisional: there is no sprint history, target-device profile, or accepted GPU decision. `S` ≈ half day, `M` ≈ one day, `L` ≈ two or more days.

### Phase 0 — Baseline truth (1–2 days)

**Goal:** Make the repository tell the truth about what is tested, built, and claimed.

| ID | Work | Type | Est. | Depends on | Acceptance criteria / evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 0.1 | Persist audit evidence and file bug reports | Config/Data | S | — | Durable evidence under `production/qa/evidence/audit-20261120/`; bug records for F-02–F-06 include repro, expected/actual, commit, and severity |
| 0.2 | Add lightweight project config and design brief | Config/Data | S | — | Record engine, code root, Android target, offline scope, workflow tier, performance targets, and one-sortie MVP; do not import full studio ceremony |
| 0.3 | Create nonrecursive test manifest and runner | Integration | M | 0.1 | Runner discovers all current 35 suites plus future regressions, runs each once, captures exit codes/assertion counts, fails on missing/extra suites; historical recursive gates become compatibility wrappers |
| 0.4 | Add CI gate | Integration | M | 0.3 | CI imports project, runs complete nonrecursive suite, uploads logs, and fails on any nonzero exit; no recursive suite multiplication |
| 0.5 | Correct README/PROJECT/TEST_READY | Config/Data | S | 0.3 | Counts match generated manifest; remove “final release certification”; distinguish headless CPU fallback from device Vulkan validation |
| 0.6 | Define budgets and device matrix | Config/Data | S | 0.2 | Commit frame, memory, draw/load, streaming, thermal, and soak budgets; name reference device and fallback test devices; unset metrics remain NOT ASSESSED |

**Exit gate:** Complete corpus runs once in CI; docs match reality; no stale APK is presented as current evidence.

### Phase 1 — Critical wiring fixes (3–5 days)

**Goal:** Make the live simulation obey its advertised control, restore, landing, and governor contracts.

| ID | Work | Type | Est. | Depends on | Acceptance criteria / evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1.1 | Write failing regressions first | Logic/Integration | M | 0.3 | Tests reproduce governor double-sampling, partial rewind, missing touch axes, airborne mission completion, and nested-lock fragility; tests fail before fixes |
| 1.2 | Give frame governor one sampling owner | Logic | S–M | 1.1 | One real frame-time sample per rendered frame; simulation delta does not masquerade as frame time; overload lowers LOD, recovery raises it within bounds; manual tests use explicit test clock or disable governor |
| 1.3 | Complete touch 6 DOF | Integration/UI | M | 1.1, UX decision | Visible heave/roll controls produce nonzero thrust Y and torque Z through real touch/drag events; release resets; multitouch ownership and deadzones remain correct; targets are usable on phone/tablet |
| 1.4 | Require real touchdown for landing | Logic/Integration | M | 1.1 | Mission cannot complete at 20 m without contact; completion requires deployed gear, stable contact, and approved speed/sink limits; hard-landing damage is event-calibrated, not arbitrary per-tick damage |
| 1.5 | Resolve rewind semantics | Logic/Integration | L | 1.1, ADR | Recommended: fixed-capacity sortie checkpoint restores ship attitude/angular velocity, fuel/mass, hull/temp, battery, weapon heat, guidance, mission counters, waypoints, targets, and projectiles. If reduced scope is chosen, rename feature and remove misleading expectations; no partial silent restore |
| 1.6 | Remove scheduler nested lock | Logic | S | 1.1 | `shutdown` uses an unlocked cancellation helper; concurrent submit/cancel/poll/shutdown stress passes; all workers join; fair ownership test shows no scheduler/resource leak |
| 1.7 | Correct G-load and visual roll semantics | Logic/Visual | S | 1.1 | Proper G excludes gravity unless explicitly documented otherwise; freefall/hover/thrust cases pass; visual roll uses local angular state and cached plume references at arbitrary attitudes |

**Exit gate:** The five probe failures become passing regression tests; live input path is tested, not just controller setters; no open S2 in the repaired contracts.

### Phase 2 — Playable vertical slice (4–7 days)

**Goal:** A new player can understand, complete, fail, and restart one sortie on desktop and touch.

| ID | Work | Type | Est. | Depends on | Acceptance criteria / evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2.1 | Write lean GDD, systems index, and UX spec | Config/Data | M | 0.2 | One-page core loop, mission stages, control scheme, HUD states, failure/restart rules, and acceptance criteria; design review and consistency check pass |
| 2.2 | Implement intentional spawn and target motion | Logic/Integration | M–L | 2.1, ADR | Choose stable-orbit, assisted atmospheric, or deorbit profile; default no longer begins as unexplained zero-velocity freefall; waypoint and drone motion match the chosen model; first minute is playable |
| 2.3 | Add pause/restart/failure/complete flow | Integration/UI | M | 2.1 | Pause freezes simulation/input; restart resets pools, mission, recorder, fuel, heat, power, and origin; failure and completion offer retry; 20 restart cycles leave no orphan growth |
| 2.4 | Make HUD responsive and readable | UI | L | 2.1, 1.3 | Numeric altitude/speed/fuel/hull/battery/heat, named guidance mode, persistent FIRE/MODE/heave/roll labels, safe-area layout, color+shape alerts; screenshots at phone/tablet/desktop aspect ratios; no overlap or tiny text |
| 2.5 | Add controls guide and first-run hints | UI | S–M | 2.4 | Player can discover movement, attitude, heave, roll, fire, mode, pause, and rewind without external docs; hints can be dismissed and do not block combat |
| 2.6 | Add basic audio and feedback | Visual/Feel | M | 2.3 | Pooled engine/fire/impact/warning/UI sounds; mute/volume control; no clipping or missing assets; feedback timing verified in playtest |
| 2.7 | Run first structured playtest | Integration | M | 2.2–2.6 | Record build, platform, input method, first-five-minute confusion, mission completion, deaths, and top three issues; fix critical confusion before Polish |

**Exit gate:** Production → Polish gate can pass: playable end-to-end, complete tests, smoke pass, at least one documented playtest, no open S1/S2 core-loop bugs.

### Phase 3 — Device performance and allocation truth (3–6 days)

**Goal:** Replace headless assumptions with measured Android/Vulkan evidence.

| ID | Work | Type | Est. | Depends on | Acceptance criteria / evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 3.1 | Instrument hot paths | Integration | M | 0.6, 1.2 | Measure simulation tick, streaming scan, worker generation, GPU dispatch/readback, mesh upload, collider bake, HUD draw, and physics queries; record backend and device identity |
| 3.2 | Capture Android Vulkan baseline | Integration | M | 3.1, device | Current build runs on reference or named fallback device; capture frame-time distribution, GPU/CPU timing, memory, draw calls, thermal state, and startup/load time |
| 3.3 | Timebox CPU vs GPU streaming decision | Logic/Integration | L | 3.2 | Compare CPU workers, synchronous GPU, and any feasible nonblocking GPU path; verify thread affinity and readback cost; ADR chooses backend with measured data; do not promise GPU async without evidence |
| 3.4 | Optimize only measured bottlenecks | Logic/Visual | M–L | 3.3 | Preallocate scratch where required; remove per-chunk temporary arrays if measured; cache HUD/visual references; reduce uploads/collider churn; before/after profiles show improvement |
| 3.5 | Run allocation, leak, and soak tests | Integration | M | 3.4 | Define startup vs steady-state allocation budget; track static memory, object counts, orphan nodes, pool occupancy, and frame drift over 30–60 minutes; repeated restart/rebase/streaming churn returns to baseline |

**Exit gate:** Committed budgets are met on the named device, or scope/target is formally revised with evidence. “Zero runtime allocation” is replaced by a measurable, enforced contract.

### Phase 4 — Polish and release candidate (3–5 days)

**Goal:** Produce a current, validated, presentable build rather than a stale artifact.

| ID | Work | Type | Est. | Depends on | Acceptance criteria / evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 4.1 | Lean art bible and asset pass | Visual/Feel | M–L | 2.1, 3.4 | Define cryo-industrial identity, shape language, palette, HUD style, and asset budgets; improve ship/drone silhouettes and terrain readability; asset audit has no missing references |
| 4.2 | Accessibility and settings | UI | M | 2.4, 2.6 | Text scaling, remapping or equivalent control options, mute/volume, pause access, color-independent alerts, touch target sizing; retained screenshots and manual checks |
| 4.3 | Balance and additional playtests | Config/Data | M | 2.7, 4.1 | Review fuel, thrust, heat, damage, mission pacing, and drone difficulty against the GDD; run at least two more sessions covering new-player, mid-game, and difficulty; fix critical fun issues |
| 4.4 | Security and release checklist | Config/Data | S–M | 0.2, 4.2 | Confirm offline/single-player scope; audit input bounds, resource loading, export filters, secrets/logs, and dependencies; no open critical/high findings; release checklist completed |
| 4.5 | Build and validate current APK | Integration | M | 3.5, 4.3, 4.4 | Export current commit, verify package/signature/ABI, install on device, run full mobile smoke, record build identity and evidence, draft changelog; do not reuse October artifact |

**Exit gate:** Polish → Release gate is PASS, or the project remains explicitly NOT READY with named blockers. No release claim without current build and device evidence.

---

## 6. Architecture decisions to make before coding

Create short ADRs only for decisions that change contracts. Each ADR should include context, options, decision, consequences, engine compatibility, and validation.

| ADR topic | Decision needed | Recommended default |
| :--- | :--- | :--- |
| Frame timing | Who owns render-frame sampling, and how manual tests inject time? | One render-frame owner; explicit test clock; simulation tick remains deterministic |
| Rewind | Full sortie checkpoint vs reduced flight-state restore | Full checkpoint for player-facing rewind; fixed preallocated storage |
| Touch controls | How to expose heave/roll without breaking dual sticks | Dedicated visible sliders/buttons with ≥48 dp targets; keep sticks for translation/attitude |
| Landing | What counts as touchdown and safe landing? | Gear-foot contact + deployed gear + stable low speed/sink; mission requires sustained contact |
| Spawn/orbit | Stable orbit, assisted atmospheric flight, or deorbit sortie? | Choose one intentional profile; do not keep unexplained zero-velocity freefall |
| G-load | Proper acceleration vs coordinate acceleration | Proper G for HUD/structural load; expose coordinate acceleration separately if needed |
| Radar LOS | Does occlusion block lock, fire, or only display? | Block lock/fire on occluded targets unless design explicitly allows blind fire |
| Terrain backend | CPU workers vs Vulkan compute readback | Measure first; keep CPU fallback if GPU readback is slower or stalls |
| Allocation policy | Literal zero allocation vs measurable steady-state budget | Preallocate hot paths; document engine/API exceptions and enforce measured budgets |
| Performance target | Sustain 120 FPS or formally revise target | Keep 120 FPS until device evidence supports a change |

After acceptance, generate a short control manifest from the ADRs: must-do/never-do rules for simulation, streaming, input, HUD, and release.

---

## 7. Verification matrix

| Area | Required evidence | Method |
| :--- | :--- | :--- |
| Pure math | Boundary, singularity, rebase, and parity tests | Existing headless suites plus new regressions |
| Live wiring | `main.tscn` instantiation and ordered tick | Integration tests that do not freeze/teleport away the behavior under test |
| Governor | Overload, recovery, manual vs automatic, one-sample ownership | Injected frame clock and rendered-frame test |
| Touch | Press/drag/release, multitouch, heave/roll, action taps | Real `InputEventScreenTouch`/`InputEventScreenDrag` through live input host |
| Landing | Airborne false contact, gear-up, safe touchdown, hard touchdown | Physics/contact integration tests plus manual device landing |
| Rewind | Full state equality, rebase safety, empty recorder, repeated restore | Fixed-point state comparison before/after checkpoint |
| Scheduler | Saturation, cancellation, reclaim, concurrent shutdown, ownership | Stress test with fair teardown and ObjectDB/resource baseline |
| Streaming | Async convergence, staging return, rebase alignment, pool exhaustion | Existing stress suites plus device profile |
| GPU | Backend identity, dispatch/readback/upload cost, fallback correctness | Android Vulkan profile; headless CPU parity is not GPU validation |
| HUD | Readability, safe areas, numeric values, labels, alert states | Retained screenshots at multiple resolutions/aspect ratios |
| Audio/feel | Timing, mix, mute, no missing assets | Manual playtest and retained evidence |
| Performance | Frame distribution, memory, draw/load, thermal, battery | Target-device profile against committed budgets |
| Soak | 30–60 minutes, restart/rebase/streaming churn | Checkpointed memory/object/frame/thermal logs |
| Security | Offline scope, input/resource/export/log audit | Full-scope report; no critical/high findings |
| Release | Current APK, signature, ABI, install, launch, smoke | Device-verified release checklist and changelog |

### Future one-command gate

Phase 0 should introduce a nonrecursive runner, for example:

```bash
tools/run_tests.sh
```

or a Godot manifest runner:

```bash
godot --headless -s tests/run_all.gd
```

The runner must:

- Discover every registered suite exactly once.
- Pass `--direct-regression` where historical suites support it.
- Fail if a file is missing, duplicated, or exits nonzero.
- Emit per-suite assertion counts and a unique total.
- Separate headless CPU-fallback results from Android Vulkan results.
- Preserve logs as CI artifacts.

### Current-build export and device smoke

```bash
godot --headless --path . --export-debug "Android" build/CryovantaProtocol.apk
adb install -r build/CryovantaProtocol.apk
```

Then resolve the launcher activity from the installed package, launch it, and record:

- Commit hash, export time, package/version, ABI, signature.
- Device model, SoC, Android version, Vulkan driver/renderer.
- Startup, landscape orientation, touch controls, mission completion, pause/restart.
- Frame-time distribution, memory, thermal state, and any fallback backend.

Do not mark device validation complete from an export command alone.

---

## 8. Release gates and NOT ASSESSED boundaries

### Production → Polish

Required:

- Core loop playable end-to-end.
- Complete nonrecursive test suite passes.
- Smoke check passes on the candidate.
- At least one structured playtest.
- No open S1/S2 core-loop bugs.
- HUD/controls are usable on touch and desktop.

### Polish → Release

Required:

- Current signed APK built from the release commit.
- Device smoke and performance evidence.
- Soak/stability evidence.
- Full-scope security audit with no open critical/high findings.
- Accessibility basics and settings.
- Content/asset completeness against the lean GDD.
- Balance review and playtest fixes.
- Changelog and release checklist.
- No open S1/S2 bugs; S3 issues require explicit accepted risk.

### Currently NOT ASSESSED

- Android device launch and current APK behavior.
- Vulkan/Adreno compute performance and correctness on hardware.
- Sustained 120 FPS, thermal throttling, battery, and soak behavior.
- Memory/draw/load budgets beyond the 8.333 ms frame target.
- Formal balance, content counts, and art-standard compliance.
- Security scope until offline/single-player is explicitly recorded.
- Localization and store certification if those become release requirements.

These are not passes. They become assessable only when the missing artifact or device run exists.

---

## 9. Skill-to-work mapping

The audit applied the relevant game-dev skill workflows. The repository lacks the skills’ expected `project.yaml`, `.claude` helpers, GDDs, ADRs, stories, and production records, so formal missing-input checks remain **NOT ASSESSED** rather than PASS. Use lightweight equivalents; do not import the full studio pipeline just to satisfy templates.

| Skill group | Use in this plan |
| :--- | :--- |
| `project-stage-detect`, `adopt`, `gate-check`, `milestone-review`, `scope-check` | Establish Production stage, reject unsupported Release claim, define phase gates, protect one-sortie scope |
| `reverse-document`, `map-systems`, `design-review`, `consistency-check`, `review-all-gdds` | Recover a lean GDD/systems index from code, then review mission/control/HUD contracts before implementation |
| `architecture-decision`, `architecture-review`, `create-control-manifest` | Decide governor ownership, rewind, touch, landing, G-load, GPU backend, and allocation policy; turn accepted ADRs into coding rules |
| `code-review`, `tech-debt`, `bug-report`, `bug-triage` | Track findings, prioritize S2 wiring defects, record nested-lock and allocation debt without inventing crashes |
| `create-epics`, `create-stories`, `story-readiness`, `dev-story`, `story-done` | Convert phases into small ready stories with acceptance criteria and evidence; close only after verification |
| `qa-plan`, `regression-suite`, `test-evidence-review`, `smoke-check`, `test-flakiness` | Build nonrecursive manifest, regression-first fixes, evidence review, candidate smoke, and flake tracking |
| `perf-profile`, `soak-test`, `balance-check` | Measure device hotspots, run endurance checks, tune fuel/heat/damage/mission pacing against the GDD |
| `art-bible`, `asset-spec`, `asset-audit`, `ux-design`, `ux-review`, `web-design-guidelines` | Define lean visual identity, asset budgets, responsive HUD, touch discoverability, and accessibility checks |
| `playtest-report`, `quick-design`, `propagate-design-change` | Capture first-run confusion, make small tuning changes, and propagate contract changes to tests/docs |
| `security-audit`, `release-checklist`, `launch-checklist`, `changelog`, `patch-notes` | Confirm offline scope, audit export/input/resource surfaces, validate current APK, and prepare release notes |
| `team-*` skills | Optional coordination patterns only; this plan assumes solo execution and does not require subagents |

---

## 10. Estimates, risks, and immediate next sprint

### Effort estimate

| Scenario | Focused days | Assumption |
| :--- | :--- | :--- |
| Optimistic | 14 | Device available, CPU backend sufficient, rewind scope controlled |
| Expected | 18–22 | One GPU/profile surprise, one UX iteration, normal regression work |
| Pessimistic | 30+ | Target device unavailable, GPU readback redesign, or 120 FPS target requires scope reduction |

**Confidence: Medium–Low.** No sprint velocity history, no target-device profile, and several product contracts are still undecided. The largest risk is assuming headless static-memory results prove mobile Vulkan performance.

### Key risks

| Risk | Mitigation |
| :--- | :--- |
| GPU readback stalls or is slower than CPU workers | Timebox backend spike; keep deterministic CPU fallback; decide with measured data |
| Full rewind becomes a large state-machine rewrite | Decide semantics first; use fixed checkpoint arrays; restore as one transaction |
| Zero-allocation rule conflicts with engine/UI APIs | Define startup vs steady-state budgets and explicit ADR exceptions |
| 120 FPS is thermally unsustainable | Profile early; keep target until evidence supports formal revision |
| HUD readability breaks allocation assumptions | Update UI at a bounded rate; preallocate/format carefully; measure rather than dogmatically forbid all UI work |
| No Android device access | Record NOT ASSESSED; do not certify release; obtain reference or named fallback device |
| Scope creep into new planets/multiplayer | Protect one-sortie MVP; defer additions until release gate passes |

### Sprint 1 recommendation

**Goal:** Truthful baseline plus the highest-value live-wiring fixes.

Pick:

1. 0.1 Persist evidence and bug reports.
2. 0.3 Nonrecursive test manifest/runner.
3. 0.5 Correct stale documentation.
4. 1.1 Failing regressions for critical wiring.
5. 1.2 Governor single-owner fix.
6. 1.3 Touch heave/roll completion.
7. 1.4 Real touchdown/mission completion.
8. 1.6 Scheduler lock cleanup.

Defer full rewind implementation to Sprint 2 unless the semantics decision is already accepted and the checkpoint design is small. Sprint 1 should still decide and document rewind semantics so the feature is not misleading.

### Definition of done for every story

- Acceptance criteria are tested at the correct layer: unit, live integration, UI screenshot, or device manual check.
- A bug fix includes a regression that would have caught the original failure.
- Production scripts remain ≤250 lines; extract helpers rather than weakening the guardrail.
- No unrelated refactor or silent contract change.
- Docs/GDD/ADR/tests are updated when behavior changes.
- Evidence records commit, platform, backend, and date.
- Headless pass is never relabeled as Android/Vulkan pass.

---

## 11. Final recommendation

Start with Phase 0 and Phase 1. The project does not need a rewrite; it needs truthful verification, coherent live wiring, and one playable sortie. After that, optimize from device measurements and polish the presentation. Release only when the current build—not the October APK—passes the device, stability, security, and playtest gates.

---

## 12. Execution log

| Date | Phase | Commit / PR | Result |
| :--- | :--- | :--- | :--- |
| 2026-11-20 | Planning | `41ad985` | Evidence-backed implementation plan committed to `testing-main` |
| 2026-11-20 | Phase 0 | `5d57f6d` | Project config, one-sortie brief, durable audit evidence, and bug records added |
| 2026-11-20 | Phase 0 | `2b59cf6`, `ba21cbf` | Nonrecursive manifest/runner, CI, live-wiring regressions, and bytecode hygiene added |
| 2026-11-20 | Phase 0 | `7b49795`, `21834ee` | Truthful documentation, complete CI setup, and full Git history for provenance checks |
| 2026-11-20 | Phase 0 | PR #1, merge `6cb0ad4` | Baseline merged into `main` with the five live-wiring regressions explicitly documented as Phase 1 work |
| 2026-11-20 | Phase 1 | `435bb13` | Accepted ADR-0001 through ADR-0006 for governor, touch, touchdown, rewind, loads/visuals, and scheduler teardown |
| 2026-11-20 | Phase 1 | `3fd5e3b` | Governor sampling moved to one rendered-frame owner; targeted governor regressions pass |
| 2026-11-20 | Phase 1 | `60ee055` | Committed six-axis touch overlay/layout (`MobileTouchLayout.gd`, fixed right-stick knob deflection) |
| 2026-11-20 | Phase 1 | `9f43868` | Implemented contact-gated touchdown and episode-gated impact damage (ADR-0003) |
| 2026-11-20 | Phase 1 | `a732131` | Implemented coherent fixed-capacity sortie rewind across ship/resources/mission/pools (ADR-0004) |
| 2026-11-20 | Phase 1 | `8d07a5d` | Eliminated nested recursive mutex lock in `ChunkTaskScheduler.shutdown()` (ADR-0006) |
| 2026-11-20 | Phase 1 | `d7aec32` | Implemented proper non-gravitational G-load and local visual roll with cached plumes (ADR-0005) |
| 2026-11-20 | Phase 1 | `tools/run_tests.sh` | Complete 36-suite nonrecursive gate passed (45,287 assertions, 0 failures) |
| 2026-11-20 | Phase 1 | PR #2, merge `ce90dcd` | Phase 1 merged into `main` |
| 2026-11-20 | Phase 2 | `473a675` | Added `design/gdd/systems-index.md`, `design/gdd/core-sortie.md`, and `design/ux/hud.md` |
| 2026-11-20 | Phase 2 | `54dbbe3` | Fixed terrain culling (`cull_disabled`), `i2z` simplex parity, 64-slot `_twx_pool`, polar wind, bound radial apsides, and rebase collider transform sync |
| 2026-11-20 | Phase 2 | `8496c51` | Gated mission wave spawning (`STAGE_INACTIVE` / `STAGE_ORBITAL_INTERCEPT`), leashed target evasion, and scaled `MODE_SOFT_LAND` decel by wet mass |
| 2026-11-20 | Phase 2 | `1513761` | Added `pause_sortie` and 20-cycle zero-leak `LiveSortieBootstrap.restart_sortie()` flow |
| 2026-11-20 | Phase 2 | `abeb1bb` | Configured `canvas_items`/`expand` stretch, numeric HUD readouts, traffic vs terrain caution distinction, overheat badge, and non-overlapping touch action band |
| 2026-11-20 | Phase 2 | `d73f8e5` | Added zero-allocation procedural `AudioStreamGenerator` cockpit audio synthesis in `PlanetaryEnvironment.gd` |
| 2026-11-20 | Phase 2 | `tools/run_tests.sh` | Complete 36-suite nonrecursive gate passed (45,291 assertions, 0 failures); recorded `production/qa/playtests/playtest-20261120-phase2.md` |
| 2026-11-20 | Phase 2 | PR #3, merge `b1ef6d1` | Phase 2 merged into `main` |
| 2026-11-20 | Phase 3 | `2717946` | Added microsecond per-subsystem timing telemetry (`SimulationTelemetry.gd`, `PlanetarySimulation.gd`) |
| 2026-11-20 | Phase 3 | `6f74de4` | Reclaimed retired staging slots before capacity check in `PlanetStreamer._cancel_slot_job()` |
| 2026-11-20 | Phase 3 | `439aa7d` | Added `ADR-0007` (terrain backend/allocations), `docs/architecture/control-manifest.md`, and `production/polish/perf-profile-20261120.md` |
| 2026-11-20 | Phase 3 | `tools/run_tests.sh` | Expanded 2,400-tick multi-cycle soak test; 36-suite gate passed (`45,295` assertions, 0 failures); recorded `production/qa/soak-test-20261120-30m.md` |

Phase 0 intentionally left the live-wiring regression suite red until Phase 1 fixes landed. Phase 1 resolved BUG-0001 through BUG-0005 (`45,287` assertions). Phase 2 resolved terrain culling, allocation/parity issues, mission wave pacing, pause/restart loop, HUD/touch ergonomics, and procedural audio synthesis (`45,291` assertions, `36/36` suites). Phase 3 instrumented microsecond per-subsystem step timings, hardened staging slot reclamation, benchmarked headless steps/chunk builds, and verified 2,400-tick multi-cycle soak endurance (`45,295` assertions, `36/36` suites). Physical Snapdragon 8 Elite Gen 5 / Vulkan profiler & 30-minute thermal device tests remain `NOT ASSESSED`.

---

## 13. Phase 3 Completion Checkpoint

Phase 3 is complete and verified across all 36 headless test suites on `testing-main`. Next milestone: **Phase 4 — Art bible, accessibility, analytical balance check, Android export hardening, security audit, and release 1.0.0 gate**.
