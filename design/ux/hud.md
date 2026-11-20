# Cryovanta Protocol — Cockpit HUD & Touch UX Specification

**Document Tier:** Standard UX Spec  
**Renderer:** [CockpitHUD.gd](../../CockpitHUD.gd) (`CanvasLayer`, `layer = 20`) + [CockpitHUDRenderer.gd](../../CockpitHUDRenderer.gd)  
**Input Layer:** [MobileTouchController.gd](../../MobileTouchController.gd) + [MobileTouchLayout.gd](../../MobileTouchLayout.gd) + [MobileTouchOverlay.gd](../../MobileTouchOverlay.gd)

## 1. Visual Hierarchy & Screen Budget

- Keep center sightline and target acquisition diamond uncluttered at `1920x1080` base resolution and responsive mobile aspect ratios.
- Primary palette anchors on high-contrast cyan/teal telemetry (`Color(0.2, 0.95, 0.86, 0.9)`) over dark translucent backing (`Color(0.015, 0.05, 0.065, 0.82)`), reserving saturated amber/orange (`Color(1.0, 0.48, 0.22, 0.95)`) strictly for cautions, overheat lockout, GPWS/traffic warnings, and hull stress.
- Zero runtime String/Node heap allocations inside steady-state `_draw` / `update_hud` paths (only change-driven or pooled immediate-mode canvas primitives).

## 2. Telemetry Instruments & Readouts

| Instrument | Source Registers (`CockpitHUD`) | Presentation Rules |
| :--- | :--- | :--- |
| **Altitude / AGL** | `displayed_altitude`, `displayed_radar_altitude` | Left instrument cluster; numeric altitude + AGL readout `[Planned Phase 2]`. |
| **Velocity & G-Load** | `displayed_vertical_speed`, `displayed_horizontal_speed`, `displayed_g_load` | Signed climb/sink indicator and non-gravitational `g_load`. |
| **Trajectory Arc** | `trajectory_points` (`64` steps), `displayed_apoapsis`, `displayed_periapsis`, `displayed_eccentricity` | Predicted ballistic/orbital path projected in 3D space. |
| **Target Lock & Lead** | `locked_target_id`, `locked_target_pos`, `locked_lead_pos`, `displayed_target_los` | Diamond target reticle + predictive ballistic lead pip; LOS occlusion indicator. |
| **Waypoint Marker** | `active_waypoint_id`, `active_waypoint_pos`, `displayed_waypoint_distance` | Nav diamond + distance to active mission beacon. |
| **Vessel Bars** | `displayed_fuel_fraction`, `displayed_battery_fraction`, `displayed_heat_load`, `displayed_hull_integrity`, `displayed_weapon_heat`, `displayed_gear_progress` | Fixed-slot gauges with explicit overheat lockout visual indicator `[Planned Phase 2]`. |
| **Guidance & Mission** | `displayed_mode`, `displayed_mission_stage`, `displayed_combat_score` | Explicit named guidance mode label (`MANUAL`, `SAS`, `HOVER`, `SOFT LAND`, etc.) and mission stage/score `[Planned Phase 2]`. |
| **Threat Banners** | `displayed_proximity_alert` (`ProximityWarningSystem`) | Separate terrain alert (`CAUTION - TERRAIN`) vs traffic/hostile proximity alert (`CAUTION - TRAFFIC`) `[Planned Phase 2]`. |
| **Pause / Retry / Controls** | Lifecycle overlay `[Planned Phase 2]` | Dismissible quick-controls hint and Mission Complete / Hull Lost retry prompt. |

## 3. Touch Control Ergonomics (`MobileTouchLayout` & `MobileTouchOverlay`)

### 3.1 Ergonomic Zone Separation
- **Top Band (`top_band_height`):** Clamped `clampf(viewport_size.y * 0.12, 64.0, 120.0)` so top action buttons never expand excessively on tall aspect ratios (`test_phase14` Tier 2.3 invariant).
- **Zero-Overlap Action Band `[Planned Phase 2]`:** Constrain top action rects (`ACTION_FIRE`, `ACTION_MODE`, `ACTION_REWIND`, plus pause/restart where surfaced) horizontally between `[344, vw - 214]` so touch targets remain clear of left/right corner HUD instrument boxes at `1920x1080` and phone viewports.
- **Left Thumb Zone:** Virtual translation dual-axis stick (`X` strafe, `Y` surge) paired with vertical heave strip.
- **Right Thumb Zone:** Virtual attitude stick (`right_stick.x` yaw, `-right_stick.y` pitch in screen draw space) paired with roll slider.
- **Stretch Scaling `[Planned Phase 2]`:** Enable `window/stretch/mode="canvas_items"` and `window/stretch/aspect="expand"` in `project.godot` so vector HUD elements and touch geometry scale cleanly across high-DPI mobile screens.
