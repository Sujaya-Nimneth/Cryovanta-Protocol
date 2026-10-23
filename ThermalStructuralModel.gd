class_name ThermalStructuralModel
extends RefCounted

## Zero-allocation atmospheric entry heating and structural load model.

const HEATING_CALIBRATION: float = 700.0

var hull_integrity: float = 100.0
var max_hull_integrity: float = 100.0
var heat_shield_load: float = 0.0
var surface_temperature_k: float = 250.0
var ambient_temperature_k: float = 250.0
var max_safe_temperature_k: float = 1400.0
var max_safe_g_load: float = 12.0
var heating_coeff: float = 1.2e-4
var cooling_rate: float = 0.8
var overheat_damage_rate: float = 15.0
var over_g_damage_rate: float = 8.0
var is_overheating: bool = false
var is_over_g: bool = false

func reset() -> void:
	hull_integrity = max_hull_integrity
	heat_shield_load = 0.0
	surface_temperature_k = ambient_temperature_k
	is_overheating = false
	is_over_g = false

func step_thermal(delta: float, air_density: float, speed: float, g_load: float) -> void:
	var dt: float = maxf(delta, 0.0)
	var rho: float = maxf(air_density, 0.0)
	var v: float = maxf(speed, 0.0)
	var q_dot: float = heating_coeff * sqrt(rho) * v * v * v * 1e-4
	q_dot *= HEATING_CALIBRATION
	var target_temp: float = ambient_temperature_k + q_dot
	if target_temp > surface_temperature_k:
		surface_temperature_k = move_toward(
			surface_temperature_k,
			target_temp,
			(target_temp - surface_temperature_k) * minf(dt * 4.0, 1.0)
		)
	else:
		surface_temperature_k = move_toward(
			surface_temperature_k,
			ambient_temperature_k,
			(surface_temperature_k - ambient_temperature_k) * minf(dt * cooling_rate, 1.0)
		)
	heat_shield_load = clampf(
		(surface_temperature_k - ambient_temperature_k)
			/ maxf(max_safe_temperature_k - ambient_temperature_k, 1.0),
		0.0,
		2.0
	)
	is_overheating = surface_temperature_k > max_safe_temperature_k
	is_over_g = g_load > max_safe_g_load
	if is_overheating:
		hull_integrity -= overheat_damage_rate * (heat_shield_load - 1.0) * dt
	if is_over_g:
		hull_integrity -= over_g_damage_rate \
			* ((g_load - max_safe_g_load) / maxf(max_safe_g_load, 0.001)) * dt
	hull_integrity = clampf(hull_integrity, 0.0, max_hull_integrity)
