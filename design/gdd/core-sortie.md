# Cryovanta Protocol — Core Sortie GDD

**Document Tier:** Standard GDD (Aligned to [design/game-brief.md](../game-brief.md))  
**Scope Rule:** Single orbital-to-surface planet (`100_000.0 m` radius), single piloted vessel, single 3-stage sortie loop, zero multiplayer or meta-progression.

## 1. Core Player Fantasy & Loop

The player pilots a 6-DOF orbital-to-surface interceptor above a procedural cryogenic world. A complete sortie transitions seamlessly from orbital/high-altitude flight down through atmospheric drag and wind shear into weaponized interception, ending in a contact-gated precision surface landing — with deterministic black-box rewind to recover from mistakes without restarting the app.

```
[Spawn / Bootstrap]
       │
       ▼
Stage 0–1: RECON ──► Fly toward active waypoint (WaypointRingBuffer)
       │
       ▼
Stage 2: INTERCEPT ──► Track, lead, and destroy hostile targets (EncounterDirector + WeaponSystem)
       │
       ▼
Stage 3: TOUCHDOWN ──► Deploy gear, descend <= 5.0 m/s total / <= 3.0 m/s sink, sustain 0.15 s surface contact
       │
       ├──► [MISSION COMPLETE] ──► Instant Sortie Restart [Planned Phase 2]
       ├──► [HULL FAILURE / FUEL CUTOFF] ──► Black-Box Rewind (R / TOUCH) or Sortie Restart [Planned Phase 2]
```

## 2. Flight & Guidance Mechanics

### 2.1 Manual 6-DOF Control (`FlightInputBindings` & `MobileTouchLayout`)

Desktop keyboard defaults (`15` actions registered via `FlightInputBindings.ensure_default_actions()`):
- **Translation (`6 axes`):** `fly_forward` (`W`), `fly_backward` (`S`), `fly_left` (`A`), `fly_right` (`D`), `fly_up` (`E`), `fly_down` (`Q`).
- **Attitude Torque (`6 axes`):** `fly_pitch_up` (`I`), `fly_pitch_down` (`K`), `fly_yaw_left` (`J`), `fly_yaw_right` (`L`), `fly_roll_left` (`U`), `fly_roll_right` (`O`).
- **Combat & Systems:** `fire_weapon` (`SPACE`), `cycle_guidance_mode` (`TAB`), `rewind_flight` (`R`).
- **Lifecycle Controls `[Planned — Phase 2]`:** Pause (`P` / `ESC`) and Sortie Restart flow.

Android touch controls (`MobileTouchOverlay` -> `MobileTouchController`):
- Left thumb zone: surge/strafe virtual stick + heave vertical bar.
- Right thumb zone: pitch/yaw virtual stick + roll slider (`MobileTouchLayout.consume_actions(sim)` routes controls cleanly into `SpaceshipController` and `EncounterDirector`).

### 2.2 Flight Guidance Modes (`FlightGuidanceSystem`)

| Mode Constant | ID | Purpose |
| :--- | :---: | :--- |
| `MODE_MANUAL` | `0` | Direct pilot torque and thrust pass-through. |
| `MODE_SAS_HOLD` | `1` | Angular velocity damping (`sas_gain`, `angular_damping`). |
| `MODE_RADIAL_UP` | `2` | Align vessel local up with planetary radial normal. |
| `MODE_RETROGRADE` | `3` | Orient nose/thrust vector against orbital velocity. |
| `MODE_HOVER` | `4` | Maintain `target_altitude` while damping tangential drift. |
| `MODE_SOFT_LAND` | `5` | Controlled radial descent toward terrain clearance (`max_descent_decel`, `touchdown_margin`). |
| `MODE_PROGRADE` | `6` | Align with orbital velocity vector. |
| `MODE_ORBIT_CIRCULARIZE` | `7` | Apply tangential delta-v toward circular orbital velocity (`circularize_gain`). |
| `MODE_WAYPOINT_INTERCEPT` | `8` | Steer cruise trajectory toward `waypoint_target_pos` (`waypoint_cruise_speed`). |

*[Planned — Phase 2]: Derive `MODE_SOFT_LAND` safe deceleration margin from live vessel wet mass and thrust-to-weight headroom.*

## 3. Combat, Heat & Evasion

- **Primary Cannon (`SpaceshipWeaponSystem` + `ProjectilePoolManager`):** 128-slot ring-buffered ballistic cannon with real-time predictive lead target solution (`locked_lead_pos`) against locked hostiles in `TargetPoolManager`.
- **Thermal Lockout (`WeaponHeatCapacitor`):** Each shot increments weapon heat; reaching thermal limit enters overheated lockout until passive cooling restores fire authority.
- **Radar Occlusion (`RadarOcclusionModel`):** Target locks are attenuated by range (`max_radar_range = 25000.0 m`) and planetary horizon curvature (`displayed_target_los`).
- **Hostile Evasion (`EncounterDirector`):** Active targets evade incoming pressure and generate proximity warnings via `ProximityWarningSystem`.
  *[Planned — Phase 2]: Reconcile `LiveSortieBootstrap.auto_spawn_waves` pacing with `MissionScenarioRunner` Stage 1/2 transitions and enforce an orbital/altitude leash during evasion so targets remain playable.*

## 4. Vessel Resource & Landing Envelope

- **Propellant (`PropellantMassModel`):** Thrust burns finite propellant, dynamically lowering vessel wet mass (`dry_mass + propellant_mass`). Exhaustion sets `fuel_depleted` and `thrust_cutoff`.
- **Power Bus (`ShipPowerBusModel`):** Balances solar array generation against avionics, guidance, and weapon draw, modeling battery storage and brownout conditions.
- **Thermal Protection (`ThermalStructuralModel`):** High-speed atmospheric transit builds `heat_shield_load`; exceeding thermal capacity damages hull integrity (`hull_integrity`).
- **Touchdown Contract (`LandingGearModel` + `MissionScenarioRunner`):** Successful sortie landing (`ADR-0003`) requires all of:
  1. `LandingGearModel` deployed (`deploy_progress >= 0.95`).
  2. Terrain clearance contact (`surface_clearance <= 0.5 m` with `has_terrain_contact == true`) held for at least `0.15 s` (`weight_on_wheels == true`).
  3. Total speed `<= 5.0 m/s` and radial sink rate `<= 3.0 m/s`.

## 5. Coherent Black-Box Rewind (`ADR-0004`)

`FlightRecorderRingBuffer` captures fixed-capacity snapshots every sample interval (preserving ship `Basis` orientation, position, velocity, angular velocity, thermal shield/hull, propellant/wet-mass/cutoff, battery/brownout, weapon heat/overheat/lock, landing gear progress, waypoints, target pool with rebuilt `free_indices`, mission stage/score, and clears active projectiles/impacts while honoring `FloatingOrigin` rebases). Holding or triggering `rewind_flight` rolls the vessel coherently backward along the recorded sortie timeline.
