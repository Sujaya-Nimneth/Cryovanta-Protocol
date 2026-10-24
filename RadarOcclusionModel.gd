class_name RadarOcclusionModel
extends RefCounted

## Fixed-state planetary horizon LOS and range-attenuated radar signal model.

var max_radar_range: float = 25000.0
var target_los_clear: bool = true
var waypoint_los_clear: bool = true
var target_signal_strength: float = 0.0
var waypoint_signal_strength: float = 0.0

func reset() -> void:
	target_los_clear = true
	waypoint_los_clear = true
	target_signal_strength = 0.0
	waypoint_signal_strength = 0.0

static func is_line_of_sight_clear(
	observer_pos: Vector3,
	target_pos: Vector3,
	planet_center: Vector3,
	planet_radius: float
) -> bool:
	var seg: Vector3 = target_pos - observer_pos
	var seg_len_sq: float = seg.length_squared()
	if seg_len_sq < 1e-12:
		return true
	var rel_obs: Vector3 = observer_pos - planet_center
	var t: float = clampf(-rel_obs.dot(seg) / seg_len_sq, 0.0, 1.0)
	var closest: Vector3 = rel_obs + seg * t
	return closest.length_squared() >= planet_radius * planet_radius

func compute_signal_strength(
	observer_pos: Vector3,
	target_pos: Vector3,
	planet_center: Vector3,
	planet_radius: float
) -> float:
	if not is_line_of_sight_clear(observer_pos, target_pos, planet_center, planet_radius):
		return 0.0
	var dist: float = observer_pos.distance_to(target_pos)
	return clampf(1.0 - dist / maxf(max_radar_range, 1.0), 0.0, 1.0)

func step_radar_los(
	ship_pos: Vector3,
	planet_center: Vector3,
	planet_radius: float,
	weapon_system: SpaceshipWeaponSystem = null,
	target_pool: TargetPoolManager = null,
	waypoints: WaypointRingBuffer = null
) -> void:
	var target_id: int = weapon_system.locked_target_id if is_instance_valid(weapon_system) else -1
	if is_instance_valid(target_pool) and target_id >= 0 \
		and target_id < target_pool.is_in_use.size() and target_pool.is_in_use[target_id]:
		var t_pos: Vector3 = target_pool.get_target_position(target_id)
		target_los_clear = is_line_of_sight_clear(ship_pos, t_pos, planet_center, planet_radius)
		target_signal_strength = compute_signal_strength(
			ship_pos, t_pos, planet_center, planet_radius
		)
	else:
		target_los_clear = true
		target_signal_strength = 0.0
	if waypoints != null and waypoints.current_waypoint_id >= 0:
		var wp_pos: Vector3 = waypoints.get_current_waypoint_position()
		waypoint_los_clear = is_line_of_sight_clear(
			ship_pos, wp_pos, planet_center, planet_radius
		)
		waypoint_signal_strength = compute_signal_strength(
			ship_pos, wp_pos, planet_center, planet_radius
		)
	else:
		waypoint_los_clear = true
		waypoint_signal_strength = 0.0
