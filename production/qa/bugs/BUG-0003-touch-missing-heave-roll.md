# BUG-0003 — Touch cannot command heave or roll

**Severity:** S2-High  
**Priority:** P1  
**Status:** Open  
**Build:** `624b68e`

## Reproduction

1. Send real touch/drag events through `MobileTouchOverlay`.
2. Inspect controller thrust and torque outputs.

**Expected:** Touch can command all advertised six degrees of freedom.  
**Actual:** Overlay always passes vertical and roll as `0.0`; only translation X/Z and pitch/yaw are reachable.

**Evidence:** `production/qa/evidence/audit-20261120/live-wiring-probe.log`  
**Files:** `MobileTouchOverlay.gd`, `MobileTouchController.gd`, `CockpitHUDRenderer.gd`
