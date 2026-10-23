class_name TargetPoolManager
extends Node3D

## Pre-allocated 32-slot target ring buffer with O(1) acquisition and release.
## All nodes, shapes, meshes, and state arrays are created before simulation ticks.

const POOL_SIZE: int = 32
const TARGET_COLLISION_LAYER: int = 4
const DEFAULT_TARGET_RADIUS: float = 3.0
const TARGET_MARKER_SCALE: Vector3 = Vector3(0.5, 0.5, 0.5)

var bodies: Array[StaticBody3D] = []
var shapes: Array[CollisionShape3D] = []
var markers: Array[MeshInstance3D] = []
var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var health: PackedFloat32Array = PackedFloat32Array()
var is_in_use: Array[bool] = []
var free_indices: Array[int] = []
var active_count: int = 0
var target_collision_layer: int = TARGET_COLLISION_LAYER
var target_collision_mask: int = 0

func _init() -> void:
	positions.resize(POOL_SIZE)
	velocities.resize(POOL_SIZE)
	health.resize(POOL_SIZE)
	is_in_use.resize(POOL_SIZE)
	free_indices.resize(POOL_SIZE)
	bodies.resize(POOL_SIZE)
	shapes.resize(POOL_SIZE)
	markers.resize(POOL_SIZE)
	for id in range(POOL_SIZE):
		is_in_use[id] = false
		free_indices[POOL_SIZE - 1 - id] = id
		_create_target_slot(id)

func _create_target_slot(id: int) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TargetBody_%d" % id
	body.collision_layer = target_collision_layer
	body.collision_mask = target_collision_mask
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = DEFAULT_TARGET_RADIUS
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "TargetCollision_%d" % id
	shape.shape = sphere
	shape.disabled = true
	body.add_child(shape)
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "TargetMarker_%d" % id
	marker.mesh = SphereMesh.new()
	marker.scale = TARGET_MARKER_SCALE
	marker.visible = false
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	add_child(body)
	bodies[id] = body
	shapes[id] = shape
	markers[id] = marker

func spawn_target(
	pos: Vector3, vel: Vector3 = Vector3.ZERO, initial_health: float = 100.0
) -> int:
	if free_indices.is_empty():
		return -1
	var id: int = free_indices.pop_back()
	positions[id] = pos
	velocities[id] = vel
	health[id] = maxf(initial_health, 0.0)
	is_in_use[id] = true
	active_count += 1
	bodies[id].position = pos
	markers[id].position = pos
	markers[id].visible = true
	shapes[id].disabled = false
	return id

func release_target(target_id: int) -> bool:
	if target_id < 0 or target_id >= POOL_SIZE or not is_in_use[target_id]:
		return false
	is_in_use[target_id] = false
	positions[target_id] = Vector3.ZERO
	velocities[target_id] = Vector3.ZERO
	health[target_id] = 0.0
	markers[target_id].visible = false
	shapes[target_id].disabled = true
	free_indices.push_back(target_id)
	active_count -= 1
	return true

func step_targets(delta: float) -> void:
	var dt: float = maxf(delta, 0.0)
	for id in range(POOL_SIZE):
		if not is_in_use[id]:
			continue
		positions[id] += velocities[id] * dt
		bodies[id].position = positions[id]
		markers[id].position = positions[id]

func find_target_by_collider(collider: Object) -> int:
	if not is_instance_valid(collider):
		return -1
	var body: StaticBody3D = null
	if collider is CollisionObject3D:
		body = collider as StaticBody3D
	if body == null:
		return -1
	for id in range(POOL_SIZE):
		if is_in_use[id] and bodies[id] == body:
			return id
	return -1

func apply_damage(target_id: int, amount: float) -> bool:
	if target_id < 0 or target_id >= POOL_SIZE or not is_in_use[target_id]:
		return false
	health[target_id] = maxf(health[target_id] - maxf(amount, 0.0), 0.0)
	if health[target_id] <= 0.0:
		release_target(target_id)
		return true
	return false

func rebase_origin(offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	for id in range(POOL_SIZE):
		if not is_in_use[id]:
			continue
		positions[id] -= offset
		bodies[id].position = positions[id]
		markers[id].position = positions[id]

func verify_integrity() -> Dictionary:
	var errors: Array[String] = []
	if bodies.size() != POOL_SIZE or shapes.size() != POOL_SIZE or markers.size() != POOL_SIZE:
		errors.append("Target node arrays must all be size %d" % POOL_SIZE)
	if positions.size() != POOL_SIZE or velocities.size() != POOL_SIZE or health.size() != POOL_SIZE:
		errors.append("Target state arrays must all be size %d" % POOL_SIZE)
	if is_in_use.size() != POOL_SIZE or free_indices.size() + active_count != POOL_SIZE:
		errors.append("Active (%d) + Free (%d) != %d" % [
			active_count, free_indices.size(), POOL_SIZE
		])
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(POOL_SIZE)
	for id in free_indices:
		if id < 0 or id >= POOL_SIZE or seen[id] != 0:
			errors.append("Invalid or duplicate free target index: %d" % id)
			continue
		seen[id] = 1
		if is_in_use[id]:
			errors.append("Free target %d is marked in use" % id)
	for id in range(POOL_SIZE):
		if id >= bodies.size():
			continue
		if is_in_use[id]:
			if seen[id] != 0:
				errors.append("Active target %d is present in free list" % id)
			if not markers[id].visible:
				errors.append("Active target %d marker is hidden" % id)
			if shapes[id].disabled:
				errors.append("Active target %d collider is disabled" % id)
		else:
			if markers[id].visible:
				errors.append("Inactive target %d marker is visible" % id)
			if not shapes[id].disabled:
				errors.append("Inactive target %d collider is enabled" % id)
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
		health[id] = 0.0
		is_in_use[id] = false
		bodies[id].position = Vector3.ZERO
		markers[id].position = Vector3.ZERO
		markers[id].visible = false
		shapes[id].disabled = true
		free_indices[id] = POOL_SIZE - 1 - id
	active_count = 0
