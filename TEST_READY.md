# Verification Status — Cryovanta Protocol

**Updated:** 2026-11-20

**Engine:** Godot `4.7.2.stable.official.ed1daf0bf`

**Release status:** NOT READY

## Current gate

```bash
bash tools/run_tests.sh
```

The runner validates `tests/manifest.txt`, imports the project, executes every registered root-level suite once with `--direct-regression`, parses final counters, and stores logs in `build/test-logs/`.

The historical Phase 14 master is retained for compatibility. Its explicit registry covers 27 suites and is not the complete corpus. Recursive historical gates are not used to inflate coverage totals.

## Baseline evidence

| Check | Result | Boundary |
| :--- | :--- | :--- |
| Phase 14 historical master | 190/190, exit 0 | Only its explicit registry ran |
| Seven omitted adversarial suites | Pass individually | Now included in the complete manifest |
| Live wiring regression | 5 expected failures before Phase 1 fixes | Governor ownership, rewind fuel/stage, touch heave/roll, airborne completion |
| Async steady-state probe | 120 visuals, 0 pending jobs, 64 staging slots free, static delta 0 | CPU-fallback pool stability, not GPU certification |
| Production guardrails | 42 scripts at baseline, all ≤250 lines | Rechecked by the corpus after changes |
| Android device/Vulkan | NOT ASSESSED | No current device run or profile |
| Thermal/soak | NOT ASSESSED | No endurance evidence |
| Current APK | NOT ASSESSED | Existing artifact predates latest baseline code |

## Known open defects

- BUG-0001: frame governor double-sampling.
- BUG-0002: partial rewind state.
- BUG-0003: touch cannot command heave or roll.
- BUG-0004: mission completion without touchdown.
- BUG-0005: scheduler shutdown nested mutex lock.

These are tracked under `production/qa/bugs/`. The live regression suite is intentionally red until the corresponding Phase 1 fixes land.

## Evidence rules

- Report suite exits and assertion counters separately; do not sum recursive runs as unique coverage.
- Record commit, engine, platform, backend, and date for every retained result.
- A headless pass never becomes an Android/Vulkan pass by relabeling.
- Missing device, balance, art-standard, security, or playtest evidence remains NOT ASSESSED.
- Release requires a current build, device smoke, performance/soak evidence, and the release checklist in `docs/implementation-plan.md`.
