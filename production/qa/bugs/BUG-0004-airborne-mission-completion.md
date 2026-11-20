# BUG-0004 — Mission completes without touchdown

**Severity:** S2-High  
**Priority:** P1  
**Status:** Verified Fixed (Phase 1 `9f43868`)  
**Build:** `624b68e`

## Reproduction

1. Enter soft-landing stage.
2. Set radar altitude to 20 m, speed to 4 m/s, and weight-on-wheels false.
3. Step the mission.

**Expected:** Completion requires deployed gear and stable physical touchdown.  
**Actual:** Mission completes while airborne. Gear contact itself is inferred from radar altitude rather than physical contact.

**Evidence:** `production/qa/evidence/audit-20261120/live-wiring-probe.log`  
**Files:** `MissionScenarioRunner.gd`, `LandingGearModel.gd`
