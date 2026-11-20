# Cryovanta Protocol — Control Manifest

**Authoritative Sources:** [FlightInputBindings.gd](../../FlightInputBindings.gd), [MobileTouchController.gd](../../MobileTouchController.gd), [MobileTouchLayout.gd](../../MobileTouchLayout.gd), [MobileTouchOverlay.gd](../../MobileTouchOverlay.gd), [PlanetarySimulation.gd](../../PlanetarySimulation.gd)

## 1. InputMap Actions (`FlightInputBindings.ACTIONS` — 17 Registered Actions)

Registered idempotently by `FlightInputBindings.ensure_default_actions()`:

| Action Name | Category | Default Key Binding(s) | Runtime Effect |
| :--- | :--- | :--- | :--- |
| `fly_forward` | Translation (`-Z` / `+Y` stick) | `W` | Forward main thrust (`thrust_input.z`) |
| `fly_backward` | Translation (`+Z` / `-Y` stick) | `S` | Retro/reverse thrust |
| `fly_left` | Translation (`-X`) | `A` | Port lateral strafe |
| `fly_right` | Translation (`+X`) | `D` | Starboard lateral strafe |
| `fly_up` | Translation (`+Y`) | `E` | Dorsal/vertical climb thrust |
| `fly_down` | Translation (`-Y`) | `Q` | Ventral/vertical descend thrust |
| `fly_pitch_up` | Attitude Torque (`+X`) | `I` | Pitch nose up |
| `fly_pitch_down` | Attitude Torque (`-X`) | `K` | Pitch nose down |
| `fly_yaw_left` | Attitude Torque (`-Y`) | `J` | Yaw left |
| `fly_yaw_right` | Attitude Torque (`+Y`) | `L` | Yaw right |
| `fly_roll_left` | Attitude Torque (`+Z`) | `U` | Counter-clockwise roll |
| `fly_roll_right` | Attitude Torque (`-Z`) | `O` | Clockwise roll |
| `fire_weapon` | Combat | `SPACE` | Fire ballistic cannon (`weapon_system.fire_projectile()`) |
| `cycle_guidance_mode` | Autopilot / SAS | `TAB` | Cycle `FlightGuidanceSystem.mode` (`0..8` mod 9) |
| `rewind_flight` | Recovery | `R` | Trigger coherent black-box rewind (`LiveSortieBootstrap.trigger_rewind`) |
| `pause_sortie` | Lifecycle | `P`, `ESCAPE` | Toggle pause (`LiveSortieBootstrap.toggle_pause`) |
| `restart_sortie` | Lifecycle | `BACKSPACE` | Full zero-leak sortie reset (`LiveSortieBootstrap.restart_sortie`) |

## 2. Mobile Dual-Stick & Touch Band Contract

Handled without runtime allocations through `MobileTouchOverlay` -> `MobileTouchController` -> `MobileTouchLayout`:

| Control Zone | Screen Geometry (`MobileTouchLayout`) | Mapped Output / Action |
| :--- | :--- | :--- |
| **Left Virtual Stick (`MOVE`)** | Origin `(STICK_MARGIN = 130.0, vh - 130.0)`, radial deadzone `0.1` | `left_stick` -> `thrust_output.x` / `thrust_output.z` |
| **Left Vertical Strip (`HEAVE`)** | `heave_rect()`, `EDGE_WIDTH = 76.0`, `EDGE_MARGIN = 12.0` | `vertical_axis` -> `thrust_output.y` (`6-DOF` vertical heave) |
| **Right Virtual Stick (`ATTITUDE`)** | Origin `(vw - 130.0, vh - 130.0)`, radial deadzone `0.1` | `right_stick` -> `torque_output.x` / `torque_output.y` (knob drawn `(x, -y)`) |
| **Right Vertical Strip (`ROLL`)** | `roll_rect()`, mirrored right edge `EDGE_WIDTH = 76.0` | `roll_axis` -> `torque_output.z` |
| **Top Action Band — `MODE`** | Clamped height `clampf(vh * 0.12, 64.0, 120.0)`, left `35%` of `[344, vw - 214]` | Sets `overlay.cycle_mode_requested` -> `guidance` mode `+1` |
| **Top Action Band — `REWIND`** | Middle `30%` of `[344, vw - 214]` | Triggers `LiveSortieBootstrap.trigger_rewind(sim)` via `MobileTouchLayout.consume_actions(sim)` |
| **Top Action Band — `FIRE`** | Right `35%` of `[344, vw - 214]` | Sets `overlay.fire_requested` -> `weapon_system.fire_projectile()` |

All touch actions enforce `x >= 344.0` and `x <= vw - 214.0` on standard viewports so buttons do not collide with the left telemetry panel (`pw <= 310.0` at `margin = 22.0`) or right mission box (`pw = 180.0` at `margin = 22.0`).
