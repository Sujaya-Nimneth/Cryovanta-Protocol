class_name WaypointRingBuffer
extends RefCounted

## Fixed 16-slot waypoint and landing-beacon ring buffer. All storage is preallocated.

const MAX_WAYPOINTS: int = 16
const DEFAULT_CAPTURE_RADIUS: float = 150.0

var positions: PackedVector3Array = PackedVector3Array()
var radii: PackedFloat32Array = PackedFloat32Array()
var is_active: PackedByteArray = PackedByteArray()
var active_count: int = 0
var current_waypoint_id: int = -1
var completed_waypoints: int = 0
var distance_to_current: float = 0.0

func _init() -> void:
	positions.resize(MAX_WAYPOINTS)
	radii.resize(MAX_WAYPOINTS)
	is_active.resize(MAX_WAYPOINTS)
	clear()

func clear() -> void:
	var index: int = 0
	while index < MAX_WAYPOINTS:
		is_active[index] = 0
		positions[index] = Vector3.ZERO
		radii[index] = DEFAULT_CAPTURE_RADIUS
		index += 1
	active_count = 0
	current_waypoint_id = -1
	completed_waypoints = 0
	distance_to_current = 0.0

func add_waypoint(pos: Vector3, capture_radius: float = DEFAULT_CAPTURE_RADIUS) -> int:
	var index: int = 0
	while index < MAX_WAYPOINTS:
		if is_active[index] == 0:
			positions[index] = pos
			radii[index] = maxf(capture_radius, 1.0)
			is_active[index] = 1
			active_count += 1
			if current_waypoint_id < 0:
				current_waypoint_id = index
			return index
		index += 1
	return -1

func add_surface_beacon(
	unit_dir: Vector3,
	planet_center: Vector3,
	planet_radius: float,
	altitude_offset: float = 50.0,
	capture_radius: float = DEFAULT_CAPTURE_RADIUS
) -> int:
	var dir: Vector3 = unit_dir.normalized()
	if dir.length_squared() < 1e-12:
		dir = Vector3.UP
	var radial_dist: float = PlanetMath.get_terrain_height(dir, planet_radius) + altitude_offset
	return add_waypoint(planet_center + dir * radial_dist, capture_radius)

func rebase_origin(offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	var index: int = 0
	while index < MAX_WAYPOINTS:
		if is_active[index] != 0:
			positions[index] -= offset
		index += 1

func step_waypoints(ship_pos: Vector3) -> bool:
	if current_waypoint_id < 0 or current_waypoint_id >= MAX_WAYPOINTS \
		or is_active[current_waypoint_id] == 0:
		_advance_to_next_active()
		if current_waypoint_id < 0:
			return false
	var dist: float = ship_pos.distance_to(positions[current_waypoint_id])
	distance_to_current = dist
	if dist > radii[current_waypoint_id]:
		return false
	is_active[current_waypoint_id] = 0
	active_count -= 1
	completed_waypoints += 1
	_advance_to_next_active()
	if current_waypoint_id >= 0:
		distance_to_current = ship_pos.distance_to(positions[current_waypoint_id])
	return true

func get_current_waypoint_position() -> Vector3:
	if current_waypoint_id >= 0 and current_waypoint_id < MAX_WAYPOINTS \
		and is_active[current_waypoint_id] != 0:
		return positions[current_waypoint_id]
	return Vector3.ZERO

func _advance_to_next_active() -> void:
	current_waypoint_id = -1
	var index: int = 0
	while index < MAX_WAYPOINTS:
		if is_active[index] != 0:
			current_waypoint_id = index
			break
		index += 1
	distance_to_current = 0.0
