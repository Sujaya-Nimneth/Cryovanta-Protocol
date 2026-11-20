# E2E Test Infra: Cryovanta Protocol

## Test Philosophy
- Opaque-box, requirement-driven suites remain at the repository root for compatibility with historical guardrails.
- Complete corpus gate: `bash tools/run_tests.sh`.
- `tests/manifest.txt` must contain every root-level `test_*.gd` suite exactly once.
- The runner passes `--direct-regression` so historical suites do not recursively execute one another.
- Pass criteria: every suite exits 0 and reports zero failed assertions.
- Headless static-memory checks are stability evidence, not proof of zero transient allocation or Android Vulkan performance.

## Feature Inventory
| # | Feature | Source | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|--------|:------:|:------:|:------:|:------:|
| F1 | Floating Origin Rebase Trigger | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ | ✓ |
| F2 | Planet Center Offset Interface | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ | ✓ |
| F3 | World Entity & Camera Rebasing | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ | ✓ |
| F4 | Zero Velocity Spike Continuity | ORIGINAL_REQUEST R1, R4 | 5 | 5 | ✓ | ✓ |
| F5 | 6-DOF Flight Controls | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ | ✓ |
| F6 | Zero Runtime Allocations | rules.md §1 | 5 | 5 | ✓ | ✓ |
| F7 | Vacuum Boundary Drag Zeroing | ORIGINAL_REQUEST R3 | 5 | 5 | ✓ | ✓ |
| F8 | Continuous Barometric Drag Profile | ORIGINAL_REQUEST R3 | 5 | 5 | ✓ | ✓ |
| F9 | Script Line Count Guardrail | rules.md §3 | 5 | 5 | ✓ | ✓ |
| F10 | Frequent Atomic Git Commits | ORIGINAL_REQUEST R5 | 5 | 5 | ✓ | ✓ |

## Test Architecture
- Test Runner: `test_floating_origin_headless.gd` (SceneTree / SceneTree script).
- Invocation: `godot --headless -s test_floating_origin_headless.gd`.
- Pass / Fail Semantics: Exit code 0 if all tests pass; non-zero if any assertion fails.
- Tiers structure:
  - **Tier 1 (Feature Coverage)**: Isolated functional verification of each feature (rebase threshold trigger, offset calculation, entity repositioning, 6-DOF surge/sway/heave/pitch/yaw/roll response, vacuum drag zeroing, density calculation, line count checking).
  - **Tier 2 (Boundary & Corner Cases)**: Threshold boundary (1999.9m no rebase vs 2000.1m rebase), atmosphere ceiling boundary (ceiling - 0.1m vs ceiling + 0.1m), stationary vessel drag (speed 0 m/s), high-speed stability, extreme coordinate shifts.
  - **Tier 3 (Cross-Feature Combinations)**: Rebase occurring while spaceship is undergoing 6-DOF thrusting and experiencing dynamic atmospheric drag; rebase with multiple registered entities; rebase with sleeping vs active physics bodies.
  - **Tier 4 (Real-World Application Scenarios)**: Atmospheric entry flight profile from vacuum orbit to planetary surface with continuous rebase triggers, verifying complete stability, velocity conservation, and zero memory leaks.
