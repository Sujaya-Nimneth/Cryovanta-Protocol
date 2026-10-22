extends Node3D

## Links the flight controller to the fixed projectile pool and terrain radar.
## All ray queries reuse one PhysicsRayQueryParameters3D instance.

@export var ship: RigidBody3D = null
@export var projectile_pool: Node3D = null
@export var planet_manager: Node = null
@export var terrain_collision_mask: int = 1

var _radar_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _muzzle_world: Vector3 = Vector3.ZERO
var _ship_forward: Vector3 = Vector3.FORWARD
var _radial_dir: Vector3 = Vector3.ZERO
var _radar_direction: Vector3 = Vector3.ZERO
var _planet_center: Vector3 = Vector3.ZERO
var _ship_velocity: Vector3 = Vector3.ZERO
var _muzzle_velocity: Vector3 = Vector3.ZERO

func _init() -> void:
	_radar_query.collision_mask = terrain_collision_mask
	_radar_query.collide_with_bodies = true
	_radar_query.collide_with_areas = false
	_radar_query.hit_from_inside = true
	_radar_query.hit_back_faces = true

func fire_projectile(
	muzzle_local_offset: Vector3 = Vector3(0.0, 0.0, -2.0),
	muzzle_speed: float = 800.0,
	lifetime: float = 5.0
) -> int:
	if not is_instance_valid(ship) or not is_instance_valid(projectile_pool):
		return -1
	_ship_velocity = ship.linear_velocity
	_ship_forward = -ship.global_transform.basis.z
	_muzzle_world = ship.global_transform * muzzle_local_offset
	_muzzle_velocity = _ship_velocity + _ship_forward * muzzle_speed
	return projectile_pool.spawn_projectile(_muzzle_world, _muzzle_velocity, lifetime)

## Returns the distance from the ship to the nearest baked terrain surface.
func measure_radar_altitude(space_state: PhysicsDirectSpaceState3D, max_range: float = 5000.0) -> float:
	if not is_instance_valid(ship) or space_state == null or max_range <= 0.0:
		return INF
	var ship_pos: Vector3 = ship.global_position
	_planet_center = _get_planet_center()
	_radial_dir = ship_pos - _planet_center
	if _radial_dir.length_squared() < 1e-12:
		return max_range
	_radar_direction = -_radial_dir.normalized()
	_radar_query.from = ship_pos
	_radar_query.to = ship_pos + _radar_direction * max_range
	_radar_query.collision_mask = terrain_collision_mask
	# intersect_ray() may reset query parameters in headless physics; set all fields explicitly.
	_radar_query.collide_with_bodies = true
	_radar_query.collide_with_areas = false
	_radar_query.hit_from_inside = true
	_radar_query.hit_back_faces = true
	var hit: Dictionary = space_state.intersect_ray(_radar_query)
	if hit.is_empty():
		return max_range
	var distance: float = ship_pos.distance_to(hit["position"])
	return minf(distance, max_range)

func _get_planet_center() -> Vector3:
	if is_instance_valid(planet_manager):
		return planet_manager.planet_center_offset
	if is_instance_valid(ship):
		return ship.get_planet_center()
	return Vector3.ZERO

func get_radar_query() -> PhysicsRayQueryParameters3D:
	return _radar_query
