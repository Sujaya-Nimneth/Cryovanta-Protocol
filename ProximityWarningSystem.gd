class_name ProximityWarningSystem
extends RefCounted

## Zero-allocation GPWS terrain and closing-target threat evaluator.

const ALERT_NONE: int = 0
const ALERT_CAUTION: int = 1
const ALERT_PULL_UP: int = 2

var caution_tti_seconds: float = 8.0
var pull_up_tti_seconds: float = 3.5
var min_altitude_caution: float = 120.0
var threat_proximity_radius: float = 250.0
var alert_level: int = ALERT_NONE
var time_to_impact: float = INF
var nearest_threat_distance: float = INF
var threat_active: bool = false

func reset() -> void:
	alert_level = ALERT_NONE
	time_to_impact = INF
	nearest_threat_distance = INF
	threat_active = false

func evaluate_proximity(
	radar_altitude: float,
	vertical_speed: float,
	ship_pos: Vector3,
	target_pool: TargetPoolManager = null
) -> int:
	if vertical_speed < -0.5:
		time_to_impact = maxf(radar_altitude, 0.0) / (-vertical_speed)
	else:
		time_to_impact = INF
	if time_to_impact <= pull_up_tti_seconds \
		or (radar_altitude <= min_altitude_caution * 0.4 and vertical_speed < -5.0):
		alert_level = ALERT_PULL_UP
	elif time_to_impact <= caution_tti_seconds \
		or (radar_altitude <= min_altitude_caution and vertical_speed < -2.0):
		alert_level = ALERT_CAUTION
	else:
		alert_level = ALERT_NONE
	nearest_threat_distance = INF
	threat_active = false
	if is_instance_valid(target_pool):
		var id: int = 0
		while id < TargetPoolManager.POOL_SIZE:
			if target_pool.is_in_use[id]:
				var distance: float = ship_pos.distance_to(target_pool.positions[id])
				if distance < nearest_threat_distance:
					nearest_threat_distance = distance
			id += 1
		if nearest_threat_distance <= threat_proximity_radius:
			threat_active = true
			if alert_level == ALERT_NONE:
				alert_level = ALERT_CAUTION
	return alert_level
