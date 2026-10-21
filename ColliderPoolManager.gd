class_name ColliderPoolManager
extends Node3D

## Pre-allocates and recycles exactly 64 ConcavePolygonShape3D / StaticBody3D slots.
## Conforms to rules.md: ZERO runtime allocations in _process or _physics_process.
## Provides O(1) acquire and release matching ChunkPoolManager.gd.

const POOL_SIZE: int = 64
static var EMPTY_FACES: PackedVector3Array = PackedVector3Array()

var bodies: Array[StaticBody3D] = []
var collision_shapes: Array[CollisionShape3D] = []
var shapes: Array[ConcavePolygonShape3D] = []
var free_indices: Array[int] = []
var is_in_use: Array[bool] = []
var collider_owners: Array[RefCounted] = []
var active_count: int = 0

func _init() -> void:
	bodies.resize(POOL_SIZE)
	collision_shapes.resize(POOL_SIZE)
	shapes.resize(POOL_SIZE)
	free_indices.resize(POOL_SIZE)
	is_in_use.resize(POOL_SIZE)
	collider_owners.resize(POOL_SIZE)
	
	for i in range(POOL_SIZE):
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "ColliderBody_%d" % i
		body.collision_layer = 0
		body.collision_mask = 0
		
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Shape3D"
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		col.shape = shape
		col.disabled = true
		
		body.add_child(col)
		add_child(body)
		
		bodies[i] = body
		collision_shapes[i] = col
		shapes[i] = shape
		free_indices[i] = i
		is_in_use[i] = false
		collider_owners[i] = null
	
	active_count = 0

## Acquires a collider slot in O(1). Returns id in [0, 63], or -1 on exhaustion.
func acquire_collider(owner_node: RefCounted) -> int:
	if free_indices.is_empty():
		push_warning("ColliderPoolManager: Pool exhausted (64/64 colliders active).")
		return -1
	
	var collider_id: int = free_indices.pop_back()
	is_in_use[collider_id] = true
	collider_owners[collider_id] = owner_node
	collision_shapes[collider_id].disabled = false
	bodies[collider_id].collision_layer = 1
	bodies[collider_id].collision_mask = 1
	active_count += 1
	return collider_id

## Releases a collider slot back into the pool in O(1).
func release_collider(collider_id: int) -> bool:
	if collider_id < 0 or collider_id >= POOL_SIZE or not is_in_use[collider_id]:
		return false
	
	is_in_use[collider_id] = false
	collider_owners[collider_id] = null
	collision_shapes[collider_id].disabled = true
	bodies[collider_id].collision_layer = 0
	bodies[collider_id].collision_mask = 0
	bodies[collider_id].position = Vector3.ZERO
	shapes[collider_id].set_faces(EMPTY_FACES)
	free_indices.push_back(collider_id)
	active_count -= 1
	return true

## Sets the chunk-local origin position of the collider StaticBody3D.
func set_collider_origin(collider_id: int, chunk_origin: Vector3) -> void:
	if collider_id >= 0 and collider_id < POOL_SIZE and is_in_use[collider_id]:
		bodies[collider_id].position = chunk_origin

func get_collider_origin(collider_id: int) -> Vector3:
	return bodies[collider_id].position if (collider_id >= 0 and collider_id < POOL_SIZE and is_in_use[collider_id]) else Vector3.ZERO

## Bakes terrain triangle faces into the pre-allocated ConcavePolygonShape3D.
func update_collider_faces(collider_id: int, faces: PackedVector3Array) -> void:
	if collider_id >= 0 and collider_id < POOL_SIZE and is_in_use[collider_id]:
		shapes[collider_id].set_faces(faces)

func get_shape(collider_id: int) -> ConcavePolygonShape3D:
	return shapes[collider_id] if (collider_id >= 0 and collider_id < POOL_SIZE) else null

func get_body(collider_id: int) -> StaticBody3D:
	return bodies[collider_id] if (collider_id >= 0 and collider_id < POOL_SIZE) else null

func get_collision_shape(collider_id: int) -> CollisionShape3D:
	return collision_shapes[collider_id] if (collider_id >= 0 and collider_id < POOL_SIZE) else null

func get_collider_owner(collider_id: int) -> RefCounted:
	return collider_owners[collider_id] if (collider_id >= 0 and collider_id < POOL_SIZE) else null

func has_available(count: int = 1) -> bool:
	return (POOL_SIZE - active_count) >= count

func get_active_count() -> int:
	return active_count

func get_free_count() -> int:
	return POOL_SIZE - active_count

## Audits pool invariants: checks for duplicates, leaks, or state inconsistencies.
func verify_integrity() -> Dictionary:
	var errors: Array[String] = []
	if bodies.is_empty():
		return {"is_valid": true, "active_count": 0, "free_count": 0, "errors": []}
	if active_count + free_indices.size() != POOL_SIZE:
		errors.append("Active (%d) + Free (%d) != Total (%d)" % [
			active_count, free_indices.size(), POOL_SIZE
		])
	
	var seen_free: Dictionary = {}
	for id in free_indices:
		if seen_free.has(id):
			errors.append("Duplicate index in free stack: %d" % id)
		seen_free[id] = true
		if is_in_use[id]:
			errors.append("Index %d is in free stack but marked in_use" % id)
	
	for i in range(POOL_SIZE):
		if is_in_use[i]:
			if seen_free.has(i):
				errors.append("Index %d marked in_use but present in free stack" % i)
			if collision_shapes[i].disabled:
				errors.append("Index %d in_use but collision_shape disabled" % i)
		else:
			if not collision_shapes[i].disabled:
				errors.append("Index %d inactive but collision_shape enabled" % i)
	
	return {
		"is_valid": errors.is_empty(),
		"active_count": active_count,
		"free_count": free_indices.size(),
		"errors": errors
	}

## Full cleanup to prevent memory/ObjectDB leaks.
func clear() -> void:
	for i in range(bodies.size()):
		if bodies[i]:
			if bodies[i].get_parent() == self:
				remove_child(bodies[i])
			bodies[i].free()
			bodies[i] = null
		collision_shapes[i] = null
		shapes[i] = null
		collider_owners[i] = null
	bodies.clear()
	collision_shapes.clear()
	shapes.clear()
	free_indices.clear()
	is_in_use.clear()
	collider_owners.clear()
	active_count = 0
