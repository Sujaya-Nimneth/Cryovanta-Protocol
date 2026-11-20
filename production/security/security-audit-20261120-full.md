# Cryovanta Protocol — Full Security & Export Hygiene Audit

**Date:** 2026-11-20  
**Scope:** All `43` production `.gd` scripts, `planet_chunk.glsl`, `project.godot`, `export_presets.cfg`, and repository dependencies  
**Multiplayer (`project.yaml`):** `platform.multiplayer: false` (offline single-player sortie)

---

## 1. Static Surface Inspection Summary

Evaluated across every production `.gd` script via direct source search (`grep`):
- **File I/O (`FileAccess` / `DirAccess`):** **Zero occurrences** in production runtime scripts (no user save serialization/deserialization surface).
- **Network / Multiplayer (`HTTPRequest` / `ENet` / `WebSocket` / `Multiplayer`):** **Zero occurrences** (offline single-player only).
- **OS Shell / Native Bridges (`OS.execute` / `JavaClassWrapper`):** **Zero occurrences** in production scripts.
- **Shader Compute Memory Layout (`planet_chunk.glsl` / `ComputeChunkDispatcher`):** Fixed `36,992`-byte `std430` storage buffer (`1,156 * 32` bytes) and `48`-byte push constants; `unpack_std430_vertex_buffer()` validates exact minimum buffer size before decoding floats.

## 2. Export Preset & Repository Hygiene Fixes Applied

- **Stale Local Binaries Removed:** Deleted stale pre-Phase-D untracked local artifacts (`build/CryovantaProtocol.apk`, `build/CryovantaProtocol.apk.idsig`, `build/runtime_preview.png`, `build/runtime_preview.png.import`).
- **`export_presets.cfg` Hardening:**
  - Updated `exclude_filter` to strip test scripts, tooling, documentation, design/QA specs, skills metadata, and `.agents`/`.antigravity` configuration from exported `.pck` packages:
    `exclude_filter="test_*.gd,tests/*,tools/*,docs/*,design/*,production/*,*.md,export_presets.cfg,icon*.svg,build/*,skills-lock.json,.agents/*,.antigravity/*"`
  - Set `gradle_build/min_sdk="26"` and `gradle_build/target_sdk="35"` (replacing blank SDK fields).

## 3. Retained Findings & Store-Release Blockers

| Severity | Finding | Current Status |
| :--- | :--- | :--- |
| **Release Blocker** | `gradle_build/use_gradle_build=false` / `export_format=0` (APK, debug keystore) | Preserved intentionally in debug preset because `test_phase14` Tier 1.2 asserts `use_gradle_build=false` and `export_path="build/CryovantaProtocol.apk"`. Google Play Store production release MUST switch to signed AAB with production keystore. |
| **Low / Design** | `pointing/emulate_touch_from_mouse=true` in `project.godot` | Retained intentionally (`test_phase14` Tier 1.1 asserts `"Mouse input emulates touch"`). |
| **Not Assessed** | PCK encryption (`encrypt_pck`) and live Android APK/AAB binary static analysis (`apkanalyzer` / Play App Signing) | `NOT ASSESSED` (no binary Android export built in headless macOS environment). |
