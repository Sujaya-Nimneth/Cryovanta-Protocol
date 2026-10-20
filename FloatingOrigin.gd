class_name FloatingOrigin
extends Node

## Floating origin coordinate rebasing system for Cryovanta Protocol.
## Monitors player vessel and translates world entities when exceeding rebase_threshold.
## Complies with rules.md:
## - Script length strictly <= 250 lines
## - Zero runtime heap memory allocations in _physics_process
## - Zero velocity spikes across rebase frame (< 1e-4 tolerance)

signal origin_rebased(offset: Vector3)

@export var rebase_threshold: float = 2000.0
@export var player_node: Node3D = null
@export var planet_manager: Node = null

var registered_entities: Array[Node3D] = []
var accumulated_offset: Vector3 = Vector3.ZERO

func _physics_process(_delta: float) -> void:
	check_rebase()

## Checks whether player exceeds rebase threshold and performs rebase if crossed.
func check_rebase() -> bool:
	if not is_instance_valid(player_node):
		return false
	var pos: Vector3 = player_node.global_position
	if pos.length_squared() > (rebase_threshold * rebase_threshold):
		rebase(pos)
		return true
	return false

## Registers a world entity to be shifted during origin rebases.
func register_entity(entity: Node3D) -> void:
	if is_instance_valid(entity) and not registered_entities.has(entity):
		registered_entities.append(entity)

## Unregisters an entity from rebasing.
func unregister_entity(entity: Node3D) -> void:
	registered_entities.erase(entity)

## Repositions player, registered entities, and planet center by -offset in a single frame.
func rebase(offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	
	accumulated_offset += offset
	
	# 1. Reposition player node
	if is_instance_valid(player_node):
		_rebase_node(player_node, offset)
	
	# 2. Reposition all registered world entities
	var entity_count: int = registered_entities.size()
	for i in range(entity_count):
		var entity: Node3D = registered_entities[i]
		if is_instance_valid(entity) and entity != player_node and entity != planet_manager:
			_rebase_node(entity, offset)
	
	# 3. Rebase planet manager
	if is_instance_valid(planet_manager):
		if planet_manager.has_method("rebase_origin"):
			planet_manager.rebase_origin(offset)
		elif "planet_center_offset" in planet_manager:
			planet_manager.planet_center_offset -= offset
			if "global_position" in planet_manager:
				planet_manager.global_position = planet_manager.planet_center_offset
		elif planet_manager is Node3D:
			_rebase_node(planet_manager as Node3D, offset)
	
	# 4. Notify listeners
	origin_rebased.emit(offset)

## Repositions a Node3D or RigidBody3D while preserving velocity and clearing interpolation buffers.
func _rebase_node(node: Node3D, offset: Vector3) -> void:
	if not is_instance_valid(node):
		return
	
	if node is RigidBody3D:
		var rb: RigidBody3D = node as RigidBody3D
		var rid: RID = rb.get_rid()
		var v_saved: Vector3 = rb.linear_velocity
		var w_saved: Vector3 = rb.angular_velocity
		var was_sleeping: bool = rb.sleeping
		
		var t: Transform3D = rb.global_transform
		t.origin -= offset
		
		# Direct PhysicsServer3D state synchronization prevents artificial velocity impulses
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v_saved)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, w_saved)
		if was_sleeping:
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, true)
		
		rb.global_transform = t
		rb.linear_velocity = v_saved
		rb.angular_velocity = w_saved
		if rb.has_method("reset_physics_interpolation"):
			rb.reset_physics_interpolation()
	else:
		node.global_position -= offset
		if node.has_method("reset_physics_interpolation"):
			node.reset_physics_interpolation()
