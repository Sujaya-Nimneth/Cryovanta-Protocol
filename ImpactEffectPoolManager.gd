class_name ImpactEffectPoolManager
extends Node3D

## Pre-allocated 32-slot impact burst pool. Decay only mutates fixed state.

const POOL_SIZE: int = 32
const IMPACT_MARKER_BASE_SCALE: float = 0.25

var markers: Array[MeshInstance3D] = []
var positions: PackedVector3Array = PackedVector3Array()
var durations: PackedFloat32Array = PackedFloat32Array()
var remaining: PackedFloat32Array = PackedFloat32Array()
var is_in_use: Array[bool] = []
var free_indices: Array[int] = []
var active_count: int = 0

func _init() -> void:
	positions.resize(POOL_SIZE)
	durations.resize(POOL_SIZE)
	remaining.resize(POOL_SIZE)
	is_in_use.resize(POOL_SIZE)
	free_indices.resize(POOL_SIZE)
	markers.resize(POOL_SIZE)
	for id in range(POOL_SIZE):
		is_in_use[id] = false
		free_indices[POOL_SIZE - 1 - id] = id
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.name = "ImpactMarker_%d" % id
		marker.mesh = EntityVisualsBuilder.get_impact_mesh()
		marker.material_override = EntityVisualsBuilder.get_impact_material()
		marker.scale = Vector3.ONE * IMPACT_MARKER_BASE_SCALE
		marker.visible = false
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)
		markers[id] = marker

func spawn_effect(pos: Vector3, duration: float = 0.35) -> int:
	if free_indices.is_empty():
		return -1
	var id: int = free_indices.pop_back()
	positions[id] = pos
	durations[id] = maxf(duration, 0.001)
	remaining[id] = durations[id]
	is_in_use[id] = true
	active_count += 1
	markers[id].position = pos
	markers[id].scale = Vector3.ONE * IMPACT_MARKER_BASE_SCALE
	markers[id].visible = true
	return id

func release_effect(effect_id: int) -> bool:
	if effect_id < 0 or effect_id >= POOL_SIZE or not is_in_use[effect_id]:
		return false
	is_in_use[effect_id] = false
	remaining[effect_id] = 0.0
	markers[effect_id].visible = false
	free_indices.push_back(effect_id)
	active_count -= 1
	return true

func step_effects(delta: float) -> void:
	var dt: float = maxf(delta, 0.0)
	for id in range(POOL_SIZE):
		if not is_in_use[id]:
			continue
		remaining[id] -= dt
		if remaining[id] <= 0.0:
			release_effect(id)
			continue
		var progress: float = 1.0 - remaining[id] / durations[id]
		markers[id].scale = Vector3.ONE * IMPACT_MARKER_BASE_SCALE * (1.0 + progress * 3.0)

func rebase_origin(offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	for id in range(POOL_SIZE):
		if not is_in_use[id]:
			continue
		positions[id] -= offset
		markers[id].position = positions[id]

func verify_integrity() -> Dictionary:
	var errors: Array[String] = []
	if markers.size() != POOL_SIZE or positions.size() != POOL_SIZE:
		errors.append("Impact marker and position arrays must be size %d" % POOL_SIZE)
	if durations.size() != POOL_SIZE or remaining.size() != POOL_SIZE:
		errors.append("Impact timing arrays must be size %d" % POOL_SIZE)
	if is_in_use.size() != POOL_SIZE or free_indices.size() + active_count != POOL_SIZE:
		errors.append("Active (%d) + Free (%d) != %d" % [
			active_count, free_indices.size(), POOL_SIZE
		])
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(POOL_SIZE)
	for id in free_indices:
		if id < 0 or id >= POOL_SIZE or seen[id] != 0:
			errors.append("Invalid or duplicate free impact index: %d" % id)
			continue
		seen[id] = 1
		if is_in_use[id]:
			errors.append("Free impact %d is marked in use" % id)
	for id in range(POOL_SIZE):
		if id >= markers.size():
			continue
		if is_in_use[id]:
			if seen[id] != 0:
				errors.append("Active impact %d is present in free list" % id)
			if not markers[id].visible:
				errors.append("Active impact %d marker is hidden" % id)
		elif markers[id].visible:
			errors.append("Inactive impact %d marker is visible" % id)
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
		durations[id] = 0.0
		remaining[id] = 0.0
		is_in_use[id] = false
		markers[id].position = Vector3.ZERO
		markers[id].scale = Vector3.ONE * IMPACT_MARKER_BASE_SCALE
		markers[id].visible = false
		free_indices[id] = POOL_SIZE - 1 - id
	active_count = 0
