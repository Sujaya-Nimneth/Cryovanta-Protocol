class_name ProjectilePoolManager
extends Node3D

## Pre-allocated 128-slot projectile ring buffer with O(1) allocation.
## Per rules.md §1, no projectile state or visuals are allocated while running.

const POOL_SIZE: int = 128
const TERRAIN_COLLISION_MASK: int = 1
const PROJECTILE_MARKER_SCALE: Vector3 = Vector3(0.08, 0.08, 0.5)

var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var lifetimes: PackedFloat32Array = PackedFloat32Array()
var is_in_use: Array[bool] = []
var free_indices: Array[int] = []
var markers: Array[Node3D] = []
var active_count: int = 0
var _ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _step_from: Vector3 = Vector3.ZERO
var _step_to: Vector3 = Vector3.ZERO
var _gravity_accel: Vector3 = Vector3.ZERO

func _init() -> void:
	positions.resize(POOL_SIZE)
	velocities.resize(POOL_SIZE)
	lifetimes.resize(POOL_SIZE)
	is_in_use.resize(POOL_SIZE)
	free_indices.resize(POOL_SIZE)
	markers.resize(POOL_SIZE)
	for i in range(POOL_SIZE):
		is_in_use[i] = false
		free_indices[POOL_SIZE - 1 - i] = i
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.name = "ProjectileMarker_%d" % i
		marker.mesh = BoxMesh.new()
		marker.scale = PROJECTILE_MARKER_SCALE
		marker.visible = false
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)
		markers[i] = marker
	_ray_query.collision_mask = TERRAIN_COLLISION_MASK
	_ray_query.collide_with_bodies = true
	_ray_query.collide_with_areas = false
	_ray_query.hit_from_inside = true
	_ray_query.hit_back_faces = true

func spawn_projectile(origin: Vector3, velocity: Vector3, lifetime: float = 5.0) -> int:
	if free_indices.is_empty():
		return -1
	var id: int = free_indices.pop_back()
	positions[id] = origin
	velocities[id] = velocity
	lifetimes[id] = maxf(lifetime, 0.0)
	is_in_use[id] = true
	active_count += 1
	var marker: Node3D = markers[id]
	marker.position = origin
	marker.visible = true
	return id

func release_projectile(projectile_id: int) -> bool:
	if projectile_id < 0 or projectile_id >= POOL_SIZE or not is_in_use[projectile_id]:
		return false
	is_in_use[projectile_id] = false
	velocities[projectile_id] = Vector3.ZERO
	lifetimes[projectile_id] = 0.0
	markers[projectile_id].visible = false
	free_indices.push_back(projectile_id)
	active_count -= 1
	return true

func step_projectiles(
	delta: float,
	space_state: PhysicsDirectSpaceState3D = null,
	planet_center: Vector3 = Vector3.ZERO,
	planet_radius: float = 100_000.0,
	surface_gravity: float = 0.0
) -> int:
	var impacted: int = 0
	var dt: float = maxf(delta, 0.0)
	var use_gravity: bool = surface_gravity != 0.0
	for id in range(POOL_SIZE):
		if not is_in_use[id]:
			continue
		lifetimes[id] -= dt
		if lifetimes[id] <= 0.0:
			release_projectile(id)
			continue
		_step_from = positions[id]
		_step_to = _step_from + velocities[id] * dt
		if use_gravity:
			_gravity_accel = AtmosphereMath.calculate_gravity_acceleration(
				_step_from, planet_center, planet_radius, surface_gravity
			)
			velocities[id] += _gravity_accel * dt
			_step_to = _step_from + velocities[id] * dt
		if space_state != null and dt > 0.0:
			_ray_query.from = _step_from
			_ray_query.to = _step_to
			var hit: Dictionary = space_state.intersect_ray(_ray_query)
			if not hit.is_empty():
				positions[id] = hit["position"]
				markers[id].position = positions[id]
				release_projectile(id)
				impacted += 1
				continue
		positions[id] = _step_to
		markers[id].position = _step_to
	return impacted

## Shifts all active projectile positions without changing velocity or lifetime.
func rebase_origin(offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	for id in range(POOL_SIZE):
		if is_in_use[id]:
			positions[id] -= offset
			markers[id].position = positions[id]

func verify_integrity() -> Dictionary:
	var errors: Array[String] = []
	if positions.size() != POOL_SIZE or velocities.size() != POOL_SIZE or lifetimes.size() != POOL_SIZE:
		errors.append("Projectile state arrays must all be size %d" % POOL_SIZE)
	if is_in_use.size() != POOL_SIZE or free_indices.size() + active_count != POOL_SIZE:
		errors.append("Active (%d) + Free (%d) != %d" % [active_count, free_indices.size(), POOL_SIZE])
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(POOL_SIZE)
	for id in free_indices:
		if id < 0 or id >= POOL_SIZE or seen[id] != 0:
			errors.append("Invalid or duplicate free projectile index: %d" % id)
			continue
		seen[id] = 1
		if is_in_use[id]:
			errors.append("Free projectile %d is marked in use" % id)
	for id in range(POOL_SIZE):
		if is_in_use[id]:
			if seen[id] != 0:
				errors.append("Active projectile %d is present in free list" % id)
			if not markers[id].visible:
				errors.append("Active projectile %d marker is hidden" % id)
		elif markers[id].visible:
			errors.append("Inactive projectile %d marker is visible" % id)
	return {
		"is_valid": errors.is_empty(),
		"active_count": active_count,
		"free_count": free_indices.size(),
		"errors": errors
	}

func clear() -> void:
	free_indices.resize(POOL_SIZE)
	for id in range(POOL_SIZE):
		positions[id] = Vector3.ZERO
		velocities[id] = Vector3.ZERO
		lifetimes[id] = 0.0
		is_in_use[id] = false
		markers[id].visible = false
		free_indices[id] = POOL_SIZE - 1 - id
	active_count = 0
