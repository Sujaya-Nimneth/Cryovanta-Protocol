# Cryovanta Protocol — Release Checklist (`1.0.0`)

**Date:** 2026-11-20  
**Engine:** Godot `4.7.2.stable.official.ed1daf0bf`  
**Target Platform:** Android ARM64 (`arm64-v8a`), Vulkan Mobile Renderer  
**Current Store Release Verdict:** **NO-GO FOR PUBLIC STORE UPLOAD (HEADLESS RC COMPLETE · HARDWARE / SIGNED AAB GATES `NOT ASSESSED`)**

---

## 1. Automated Verification & Engineering Gates

| Gate Item | Status | Evidence / Reference |
| :--- | :---: | :--- |
| Full nonrecursive 36-suite test gate (`tools/run_tests.sh`) | **PASS** | `36/36` suites (`45,296` reported assertions, `0` failures) |
| Production script invariants (`43` scripts, `class_name`, frozen caps) | **PASS** | Enforced by `test_phase14` & `test_adversarial_phaseE_challenger2` |
| Steady-state zero heap growth (`1k–2k` ticks + 20-cycle restart + 2,400-tick soak) | **PASS (Headless)** | Verified in `test_live_wiring_regression.gd`, `test_phase15`, `test_adversarial_phaseE_*` |
| Architecture Decision Records (`ADR-0001..0007`) & Control Manifest | **COMPLETE** | `docs/architecture/` |
| Design Specs (Systems Index, Core Sortie, HUD UX, Art Bible, Accessibility, Balance) | **COMPLETE** | `design/` (`systems-index.md`, `core-sortie.md`, `hud.md`, `art-bible.md`, `accessibility-requirements.md`, `balance-check-sortie-20261120.md`) |

## 2. Export & Security Hygiene Gates

| Check | Status | Notes |
| :--- | :---: | :--- |
| `export_presets.cfg` exclusion filter (`tests/*`, `tools/*`, `docs/*`, `design/*`, `production/*`, `.agents/*`, `skills-lock.json`) | **DONE** | Prevents non-runtime tests/docs from packaging into `.pck` |
| Android SDK API targets (`min_sdk="26"`, `target_sdk="35"`, `arm64-v8a=true`) | **DONE** | Updated in [export_presets.cfg](../../export_presets.cfg) |
| Stale local pre-Phase-D `build/CryovantaProtocol.apk*` & `build/runtime_preview.png*` removed | **DONE** | Deleted stale local October artifacts |
| Production runtime I/O / Network / Shell surface audit (`security-audit-20261120-full.md`) | **PASS** | Offline single-player (`platform.multiplayer: false`); zero File/Net/OS bridge calls |

## 3. Physical Hardware & Store-Distribution Blockers (`NOT ASSESSED`)

Before shipping to Google Play Production:
- [ ] Switch `export_presets.cfg` from debug APK (`use_gradle_build=false`, `export_format=0`) to signed Android App Bundle (`.aab`, release keystore outside repo).
- [ ] Run real Vulkan Mobile device smoke, GPU compute verification (`ComputeChunkDispatcher.use_gpu == true`), and 30-minute thermal soak on Snapdragon 8 Elite Gen 5 / Adreno 840 hardware.
- [ ] Complete live human touch/audio/difficulty playtest sign-off across portrait/landscape notches.
