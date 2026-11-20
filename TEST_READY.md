# Verification Status — Cryovanta Protocol

**Updated:** 2026-11-20

**Engine:** Godot `4.7.2.stable.official.ed1daf0bf`

**Release status:** HEADLESS RC VERIFIED (`36/36` suites) · PHYSICAL ANDROID/VULKAN `NOT ASSESSED`

## Current gate

```bash
GODOT_BIN=/opt/homebrew/bin/godot bash tools/run_tests.sh
```

The runner validates `tests/manifest.txt`, imports the project, executes every registered root-level suite once with `--direct-regression`, parses final counters, and stores logs in `build/test-logs/`.

## Verified Phase 1–4 Evidence (`testing-main`)

| Check | Result | Boundary |
| :--- | :--- | :--- |
| Full 36-suite nonrecursive gate | **PASS (`36/36`, `45,296` assertions)** | macOS `--headless` CPU simulation (`tools/run_tests.sh`) |
| Seven formerly omitted adversarial suites | **PASS** | Registered and executed inside `tests/manifest.txt` |
| Live wiring & soak suite (`test_live_wiring_regression.gd`) | **PASS (`29/29`)** | Governor ownership, coherent rewind, 6-axis touch, 0.15 s touchdown, 20-cycle restart, 2,400-tick soak |
| Production guardrails | **PASS (`43` scripts, all `<= 250` lines)** | Frozen line ceilings verified after every phase |
| Android device / Vulkan Mobile GPU compute & draw calls | **NOT ASSESSED** | No physical Snapdragon 8 Elite Gen 5 / Adreno 840 profiler capture |
| 30-minute physical hardware thermal soak | **NOT ASSESSED** | Automated 2,400-tick headless soak ran; hardware endurance pending |
| Play Store signed AAB & human playtest | **NOT ASSESSED** | Debug preset hardened (`min_sdk="26"`, `target_sdk="35"`); store AAB deferred ([release-checklist-1.0.0.md](production/releases/release-checklist-1.0.0.md)) |

## Resolved Baseline Bugs

- **BUG-0001..0005** (`production/qa/bugs/`): Verified Fixed across Phases 1–2 (`frame governor double-sampling`, `partial rewind`, `touch missing heave/roll`, `airborne mission completion`, and `scheduler nested lock`).

## Evidence rules

- Report suite exits and assertion counters separately; do not sum recursive runs as unique coverage.
- Record commit, engine, platform, backend, and date for every retained result.
- A headless pass never becomes an Android/Vulkan pass by relabeling.
- Missing device, balance, art-standard, security, or playtest evidence remains NOT ASSESSED.
- Release requires a current build, device smoke, performance/soak evidence, and the release checklist in `docs/implementation-plan.md`.
