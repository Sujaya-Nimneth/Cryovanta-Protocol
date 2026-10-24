class_name ShipPowerBusModel
extends RefCounted

## Fixed-state spacecraft power bus with solar generation and eclipse shadowing.

var enabled: bool = false
var sun_direction: Vector3 = Vector3(0.0, 1.0, 0.0)
var max_battery_wh: float = 500.0
var battery_wh: float = 500.0
var solar_charge_rate: float = 35.0
var avionics_base_drain: float = 6.0
var thruster_max_drain: float = 24.0
var weapon_heat_cooling_drain: float = 10.0
var in_eclipse: bool = false
var brownout: bool = false
var net_power_rate: float = 0.0

func reset() -> void:
	battery_wh = max_battery_wh
	in_eclipse = false
	brownout = false
	net_power_rate = 0.0

func get_battery_fraction() -> float:
	return clampf(battery_wh / maxf(max_battery_wh, 0.001), 0.0, 1.0)

func is_position_in_eclipse(
	ship_pos: Vector3,
	planet_center: Vector3,
	planet_radius: float
) -> bool:
	var sun_dir: Vector3 = sun_direction.normalized() \
		if sun_direction.length_squared() > 1e-12 else Vector3.UP
	var rel: Vector3 = ship_pos - planet_center
	var proj: float = rel.dot(sun_dir)
	if proj >= 0.0:
		return false
	var perp_sq: float = maxf(rel.length_squared() - proj * proj, 0.0)
	return perp_sq < planet_radius * planet_radius

func step_power_bus(
	delta: float,
	ship_pos: Vector3,
	planet_center: Vector3,
	planet_radius: float,
	throttle_norm: float,
	weapon_heat_norm: float,
	weapon_capacitor: WeaponHeatCapacitor = null
) -> float:
	in_eclipse = is_position_in_eclipse(ship_pos, planet_center, planet_radius)
	if not enabled:
		brownout = false
		net_power_rate = 0.0
		return get_battery_fraction()

	var dt: float = maxf(delta, 0.0)
	var charge: float = 0.0 if in_eclipse else solar_charge_rate
	var drain: float = avionics_base_drain \
		+ clampf(throttle_norm, 0.0, 1.0) * thruster_max_drain \
		+ clampf(weapon_heat_norm, 0.0, 1.0) * weapon_heat_cooling_drain
	net_power_rate = charge - drain
	battery_wh = clampf(battery_wh + net_power_rate * dt, 0.0, max_battery_wh)
	brownout = battery_wh <= 0.0
	if brownout and weapon_capacitor != null and weapon_capacitor.enabled:
		weapon_capacitor.overheated = true
		weapon_capacitor.cooldown_remaining = maxf(
			weapon_capacitor.cooldown_remaining, weapon_capacitor.fire_interval
		)
	return get_battery_fraction()
