# BUG-0001 — Frame governor double-sampling

**Severity:** S2-High  
**Priority:** P1  
**Status:** Open  
**Build:** `624b68e`

## Reproduction

1. Run `main.tscn` with `auto_step = true`.
2. Observe `EncounterDirector.step_director()` sampling `delta * 1000.0`.
3. Observe `PlanetarySimulation._physics_process()` sampling wall-clock time afterward.
4. Run manual/headless steps; only the nominal-delta path executes.

**Expected:** One owner samples real frame time once per rendered frame; simulation tick remains separate.  
**Actual:** Automatic mode samples twice; manual tests never exercise the wall-clock path.

**Files:** `EncounterDirector.gd`, `PlanetarySimulation.gd`, `FrameBudgetGovernor.gd`
