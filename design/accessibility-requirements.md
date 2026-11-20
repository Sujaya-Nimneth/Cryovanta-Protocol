# Cryovanta Protocol — Accessibility Requirements Specification

**Target Tier:** Standard Accessibility Tier (Solo / Touch + Desktop + Gamepad Cockpit Action)  
**Grounded Modules:** [FlightInputBindings.gd](../../FlightInputBindings.gd), [MobileTouchLayout.gd](../../MobileTouchLayout.gd), [CockpitHUDRenderer.gd](../../CockpitHUDRenderer.gd), [PlanetaryEnvironment.gd](../../PlanetaryEnvironment.gd), [project.godot](../../project.godot)

---

## 1. Non-Color Redundancy (100% of Critical Telemetry & Alerts)

No gameplay state relies on hue alone:
- **GPWS & Threat Alerts:** Use both severity prefix markers and distinct banner box geometry: `[!] CAUTION - TERRAIN`, `[!] CAUTION - TRAFFIC` (`2.0 px` border), and `[!!] PULL UP - TERRAIN` (`2.5 px` border, slightly wider rect).
- **Target Lock & LOS:** Clear lock displays square target reticle + `"LOCK"`; horizon occlusion adds a diagonal cross-slash line across the reticle plus `"OCCLUDED"` label.
- **Weapon Overheat:** Pairs amber bar coloring with an explicit `"OVERHEAT"` text lockout indicator next to `WPN`.
- **Resource & Telemetry Gauges:** Left telemetry bars (`ALT`, `RAD`, `V/S`, `SPD`, `G`, `FUEL`) display direct numeric SI text readouts alongside bar fill widths, plus explicit text labels for guidance modes (`MANUAL`, `SAS HOLD`, `HOVER`, `SOFT LAND`, etc.) and mission score (`SCORE: N`).

## 2. Motor & Input Accessibility

- **Three Coexisting Control Schemes (`control-manifest.md`):**
  1. Full 6-DOF Keyboard (`W/S/A/D/E/Q`, `I/K/J/L/U/O`, `SPACE`, `TAB`, `R`, `P`/`ESC`, `BACKSPACE`).
  2. Dual-Stick + Strip Mobile Touch (`MobileTouchOverlay` / `MobileTouchController` with configurable radial `deadzone = 0.1` and separated `[344, vw - 214]` top action buttons).
  3. **Standard Gamepad Fallback (`FlightInputBindings`):** Left analog stick (`JOY_AXIS_LEFT_X/Y`) translation, Right analog stick (`JOY_AXIS_RIGHT_X/Y`) pitch/yaw, bumpers (`LB`/`RB`) vertical heave, D-pad Left/Right roll, `A` or Right Trigger fire weapon, `Y` cycle guidance, `X` rewind, `Start` pause, `Back` restart.
- **Forgiveness & Assist Mechanics:**
  - **9-Mode Autopilot (`FlightGuidanceSystem`):** Assists players struggling with raw 6-DOF attitude or surface touchdown via `SAS HOLD`, `RADIAL UP`, `HOVER`, `SOFT LAND`, `PROGRADE`, `CIRCULARIZE`, and `INTERCEPT`.
  - **Coherent Sortie Rewind & Pause (`LiveSortieBootstrap`):** Instant non-punitive time rewind (`R` / touch `REWIND` / gamepad `X`) and pause at any moment (`P`/`ESC` / `Start`).

## 3. Visual & Audio Readability

- **Responsive Display Scaling:** `project.godot` sets `window/stretch/mode="canvas_items"` and `window/stretch/aspect="expand"` so HUD gauges and touch regions scale proportionally with display resolution instead of collapsing to sub-millimeter pixels.
- **Zero Blocking Audio Cues:** Procedural audio (`PlanetaryEnvironment`) reinforces thruster, weapon, and GPWS state, while visual cockpit banners and gauges always surface identical warnings without requiring sound output.

## 4. Deferred / Out-of-Scope for MVP (`NOT ASSESSED` in Release 1.0.0)

Per [design/game-brief.md](../game-brief.md) one-sortie scope: full UI string localization tables (`tr()`), runtime in-app settings menu UI (colorblind shader swap / custom key rebinding GUI / font size slider), and on-device screen reader hooks remain post-1.0.0 enhancements and are documented honestly as unimplemented here.
