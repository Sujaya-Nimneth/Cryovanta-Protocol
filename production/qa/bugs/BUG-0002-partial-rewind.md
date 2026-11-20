# BUG-0002 — Rewind restores partial sortie state

**Severity:** S2-High  
**Priority:** P1  
**Status:** Verified Fixed (Phase 1 `a732131`)  
**Build:** `624b68e`

## Reproduction

1. Record a snapshot with fuel 600 and mission stage intercept.
2. Change fuel to 100 and mission stage to failed.
3. Trigger rewind.

**Expected:** A player-facing rewind restores a coherent documented state.  
**Actual:** Position and hull restore; fuel remains 100 and mission stage remains failed. Attitude, battery, targets, projectiles, and waypoints are also not captured.

**Evidence:** `production/qa/evidence/audit-20261120/live-wiring-probe.log`  
**Files:** `FlightRecorderRingBuffer.gd`, `LiveSortieBootstrap.gd`
