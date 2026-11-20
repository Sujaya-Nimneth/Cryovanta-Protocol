# Cryovanta Protocol — Analytical Sortie Balance Check

**Date:** 2026-11-20  
**Scope:** Single-planet orbital-to-surface sortie (`100_000.0 m` radius, `9.81 m/s²` surface gravity)  
**Human Playtest Balance Feel:** `NOT ASSESSED` (analytical inspection of shipped simulation formulas only)

---

## 1. Propellant & $\Delta v$ Budget ([PropellantMassModel.gd](../../PropellantMassModel.gd), [SpaceshipController.gd](../../SpaceshipController.gd))

| Parameter | Shipped Value | Derived Analytical Result |
| :--- | :---: | :--- |
| Dry Mass (`dry_mass`) | `1,000.0 kg` | Post-burnover inertial baseline |
| Propellant Load (`max_propellant_mass`) | `600.0 kg` | Initial wet mass `1,600.0 kg` (`37.5%` propellant mass fraction) |
| Specific Impulse (`specific_impulse_s`) | `380.0 s` | Exhaust velocity `3,726.53 m/s` (`380.0 * 9.80665`) |
| Total $\Delta v$ (`v_e * ln(1600 / 1000)`) | **`1,751.48 m/s`** | Covers descent, intercept maneuvers, and orbital circularization inside atmosphere/low orbit |
| Full Forward Burn (`50,000 N`) | `13.42 kg/s` mass flow | `~44.72 s` sustained max main-engine burn before `fuel_depleted = true` |

## 2. Soft-Landing Deceleration Authority ([FlightGuidanceSystem.gd](../../FlightGuidanceSystem.gd))

- Vertical thrusters produce `vertical_thrust = 25,000.0 N`.
- At **wet mass (`1,600.0 kg`)**: upward acceleration is `15.625 m/s²`; net vertical braking headroom against `9.81 m/s²` gravity is `5.815 m/s²`.
- **Phase 2 Fix (`MODE_SOFT_LAND`):** `eff_decel = minf(max_descent_decel = 8.0, headroom * 0.85)` yields **`4.943 m/s²`** effective braking limit at full propellant load (retaining a `15%` control margin) while scaling smoothly up toward `8.0 m/s²` as propellant burns toward `1,000.0 kg` dry mass (`15.19 m/s²` headroom).
- **Touchdown Contract (`ADR-0003`):** `deployed = true` (`deploy_progress >= 0.95`), `weight_on_wheels = true` (`>= 0.15 s` sustained surface contact `<= 0.5 m`), total speed `<= 5.0 m/s`, sink rate `<= 3.0 m/s`.

## 3. Weapon Thermal Cycle ([WeaponHeatCapacitor.gd](../../WeaponHeatCapacitor.gd))

- Parameters: `max_heat = 100.0`, `heat_per_shot = 18.0`, `cooling_rate = 28.0 /s`, `fire_interval = 0.12 s`, `overheat_clear_ratio = 0.5`.
- Over one `0.12 s` fire interval, passive cooling removes `3.36` units (`net +14.64/shot`).
- Sustained rapid fire overheats cleanly on the **7th consecutive shot** (`>= 100.0`), enforcing a **`~1.79 s` lockout** (`50.0 / 28.0`) until `heat <= 50.0` — surfaced on HUD with explicit `OVERHEAT` text alongside the amber bar.

## 4. Power Bus & Thermal Envelope ([ShipPowerBusModel.gd](../../ShipPowerBusModel.gd), [ThermalStructuralModel.gd](../../ThermalStructuralModel.gd))

- **Power Bus:** `max_battery_wh = 500.0`, `solar_charge_rate = 35.0`, `avionics_base_drain = 6.0`, `thruster_max_drain = 24.0`, `weapon_heat_cooling_drain = 10.0`.Peak combat + max-thrust load (`40.0`) exceeds sunlit solar supply (`35.0`) by `5.0`, creating slow battery draw only under continuous peak output, while full eclipse removes solar supply (`-6.0` avionics idle up to `-40.0` peak load).
- **Structural / Thermal Limits:** `hull_integrity = 100.0`, `max_safe_temperature_k = 1400.0 K` (`overheat_damage_rate = 15.0/s`), `max_safe_g_load = 12.0 G` (`over_g_damage_rate = 8.0/s`). Proper non-gravitational `g_load` (`ADR-0005`) prevents false over-G alarms during vacuum freefall (`~0 G`) while preserving overload damage during extreme high-G maneuvers.

## 5. Balance Verdict

- **Analytical / Constraint Balance:** **HEALTHY** (wet-mass deceleration deficit resolved, finite propellant/weapon/thermal limits verified algebraically and in headless suites).
- **Subjective Combat / Difficulty Feel:** `NOT ASSESSED` (requires live human playtesting on device/desktop).
