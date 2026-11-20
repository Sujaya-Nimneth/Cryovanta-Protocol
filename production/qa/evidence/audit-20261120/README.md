# Audit Evidence — 2026-11-20

Baseline commit: `624b68e`  
Engine: Godot `4.7.2.stable.official.ed1daf0bf`

This directory preserves the audit evidence used to write `docs/implementation-plan.md`.

## Results

- Phase 14 master: 190/190 assertions, exit 0, but only its explicit 27-suite registry ran.
- Seven omitted adversarial suites passed individually.
- Live wiring probe: five failures — rewind fuel, rewind mission stage, touch heave, touch roll, and airborne mission completion.
- Async steady-state probe: 120 visuals, zero pending jobs, all 64 staging slots returned, static memory delta zero.
- Mutex probe: recursive `try_lock()` succeeded on this Godot build; nested scheduler locking is fragile, not a confirmed deadlock.
- APK and runtime preview are dated 2026-10-28; latest baseline code commits are dated 2026-11-02.

## Boundaries

Headless CPU-fallback results do not certify Android Vulkan performance, allocation behavior, thermal stability, or device input. Those remain NOT ASSESSED until a current build is profiled on hardware.
