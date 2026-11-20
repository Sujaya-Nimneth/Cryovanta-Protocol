class_name LandingGearModel
extends RefCounted

## Fixed-state landing gear actuator, drag modifier, and touchdown absorber.

const CONTACT_PERSIST_SECONDS: float = 0.15
const MIN_DEPLOY_PROGRESS: float = 0.95

var enabled: bool = false
var deployed: bool = true
var deploy_progress: float = 1.0
var transition_speed: float = 1.5
var auto_deploy_altitude: float = 200.0
var auto_retract_altitude: float = 400.0
var retracted_drag_coeff: float = 0.5
var deployed_drag_coeff: float = 0.85
var contact_altitude_threshold: float = 4.0
var max_safe_sink_rate: float = 8.0
var gear_up_damage_rate: float = 45.0
var hard_landing_damage_scale: float = 4.0
var compression_ratio: float = 0.0
var weight_on_wheels: bool = false
var physical_contact: bool = false
var surface_clearance: float = INF
var contact_duration: float = 0.0
var _last_damage_kind: int = 0

func reset() -> void:
	deployed = true
	deploy_progress = 1.0
	compression_ratio = 0.0
	weight_on_wheels = false
	physical_contact = false
	surface_clearance = INF
	contact_duration = 0.0
	_last_damage_kind = 0

func get_effective_drag_coefficient() -> float:
	return lerpf(
		retracted_drag_coeff, deployed_drag_coeff, clampf(deploy_progress, 0.0, 1.0)
	)

func step_gear(
	delta: float,
	radar_altitude: float,
	vertical_speed: float,
	ship: SpaceshipController = null,
	thermal: ThermalStructuralModel = null,
	has_contact: int = -1,
	clearance_override: float = -1.0
) -> float:
	surface_clearance = clearance_override if clearance_override >= 0.0 else maxf(radar_altitude - 2.0, 0.0)
	if not enabled:
		physical_contact = (has_contact == 1) if has_contact >= 0 else (radar_altitude <= contact_altitude_threshold)
		weight_on_wheels = deployed and physical_contact and radar_altitude <= contact_altitude_threshold
		compression_ratio = 0.0
		contact_duration = CONTACT_PERSIST_SECONDS if weight_on_wheels else 0.0
		_last_damage_kind = 0
		return deploy_progress
	var dt: float = maxf(delta, 0.0)
	if radar_altitude <= auto_deploy_altitude:
		deployed = true
	elif radar_altitude >= auto_retract_altitude:
		deployed = false
	var target_prog: float = 1.0 if deployed else 0.0
	deploy_progress = move_toward(deploy_progress, target_prog, transition_speed * dt)
	if is_instance_valid(ship):
		ship.drag_coefficient = get_effective_drag_coefficient()
	physical_contact = (has_contact == 1) if has_contact >= 0 else (radar_altitude <= contact_altitude_threshold)
	if physical_contact:
		contact_duration += dt
		var sink_rate: float = maxf(-vertical_speed, 0.0)
		compression_ratio = clampf(
			1.0 - radar_altitude / maxf(contact_altitude_threshold, 0.001), 0.0, 1.0
		)
		weight_on_wheels = deployed and deploy_progress >= MIN_DEPLOY_PROGRESS and contact_duration >= CONTACT_PERSIST_SECONDS
		if thermal != null:
			if deploy_progress < MIN_DEPLOY_PROGRESS and sink_rate > 1.0 and _last_damage_kind != 2:
				_last_damage_kind = 2
				thermal.hull_integrity = clampf(
					thermal.hull_integrity - gear_up_damage_rate, 0.0, thermal.max_hull_integrity
				)
			elif deploy_progress >= MIN_DEPLOY_PROGRESS and sink_rate > max_safe_sink_rate and _last_damage_kind != 1:
				_last_damage_kind = 1
				var excess: float = sink_rate - max_safe_sink_rate
				thermal.hull_integrity = clampf(
					thermal.hull_integrity - excess * hard_landing_damage_scale, 0.0, thermal.max_hull_integrity
				)
	else:
		weight_on_wheels = false
		compression_ratio = 0.0
		contact_duration = 0.0
		_last_damage_kind = 0
	return deploy_progress
