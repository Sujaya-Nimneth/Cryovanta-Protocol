class_name ChunkPoolManager
extends RefCounted

## Pre-allocates and recycles exactly 256 ArrayMesh instances.
## Conforms to .antigravity/rules.md: ZERO runtime allocations in update loops.
## Uses a fixed-size ring buffer / free-stack for O(1) allocation and recycling.

const POOL_SIZE: int = 256

var meshes: Array[ArrayMesh] = []
var free_indices: Array[int] = []
var is_in_use: Array[bool] = []
var mesh_owners: Array[RefCounted] = []
var active_count: int = 0

func _init() -> void:
	meshes.resize(POOL_SIZE)
	free_indices.resize(POOL_SIZE)
	is_in_use.resize(POOL_SIZE)
	mesh_owners.resize(POOL_SIZE)
	
	for i in range(POOL_SIZE):
		meshes[i] = ArrayMesh.new()
		free_indices[i] = i
		is_in_use[i] = false
		mesh_owners[i] = null
	
	active_count = 0

## Acquires a mesh from the pre-allocated pool in O(1).
## Returns mesh_id in [0, 255], or -1 if the pool is exhausted.
func acquire_mesh(owner_node: RefCounted) -> int:
	if free_indices.is_empty():
		push_warning("ChunkPoolManager: Pool exhausted (256/256 meshes active).")
		return -1
	
	var mesh_id: int = free_indices.pop_back()
	is_in_use[mesh_id] = true
	mesh_owners[mesh_id] = owner_node
	active_count += 1
	return mesh_id

## Recycles a mesh back into the pool in O(1).
## Returns true on success, false if invalid or already released.
func release_mesh(mesh_id: int) -> bool:
	if mesh_id < 0 or mesh_id >= POOL_SIZE:
		return false
	if not is_in_use[mesh_id]:
		return false
	
	is_in_use[mesh_id] = false
	mesh_owners[mesh_id] = null
	free_indices.push_back(mesh_id)
	active_count -= 1
	return true

## Returns the pre-allocated ArrayMesh for the given mesh_id.
func get_mesh(mesh_id: int) -> ArrayMesh:
	if mesh_id >= 0 and mesh_id < POOL_SIZE:
		return meshes[mesh_id]
	return null

## Checks if at least `count` meshes are free without allocating.
func has_available(count: int = 1) -> bool:
	return (POOL_SIZE - active_count) >= count

## Returns the count of currently active/claimed meshes.
func get_active_count() -> int:
	return active_count

## Returns the count of currently available/unclaimed meshes.
func get_free_count() -> int:
	return POOL_SIZE - active_count

## Audits pool integrity: checks for double-frees or leaking indices.
func verify_integrity() -> Dictionary:
	var errors: Array[String] = []
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
		if is_in_use[i] and seen_free.has(i):
			errors.append("Index %d is marked in_use but present in free stack" % i)
	
	return {
		"is_valid": errors.is_empty(),
		"active_count": active_count,
		"free_count": free_indices.size(),
		"errors": errors
	}

## Clean teardown to prevent ObjectDB leaks at exit
func clear() -> void:
	for i in range(POOL_SIZE):
		meshes[i] = null
		mesh_owners[i] = null
	meshes.clear()
	free_indices.clear()
	is_in_use.clear()
	mesh_owners.clear()
	active_count = 0
