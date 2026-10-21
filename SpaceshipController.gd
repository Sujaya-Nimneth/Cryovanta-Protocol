class_name SpaceshipController
extends RigidBody3D

## 6-DOF Spaceship flight controller with Dynamic Atmospheric Drag.
## Complies with rules.md:
## - Script length strictly <= 250 lines
## - Zero runtime heap memory allocations in _physics_process
## - Velocity continuity across origin rebases (< 1e-4 tolerance)

# Planetary Environment Configuration
@export var planet_manager: Node = null
@export var planet_position: Vector3 = Vector3.ZERO
@export var planet_radius: float = 100_000.0
@export var atmosphere_ceiling: float = 10_000.0
@export var surface_air_density: float = 1.225
@export var enable_planetary_gravity: bool = false
@export var surface_gravity: float = 9.81

# Aerodynamics
@export var drag_coefficient: float = 0.5
@export var cross_sectional_area: float = 10.0

# Propulsion Forces (Newtons)
@export var forward_thrust: float = 50_000.0
@export var reverse_thrust: float = 25_000.0
@export var strafe_thrust: float = 20_000.0
@export var vertical_thrust: float = 25_000.0

# Attitude Torques (Newton * meters)
@export var pitch_torque: float = 10_000.0
@export var yaw_torque: float = 8_000.0
@export var roll_torque: float = 12_000.0

# Control Settings
@export var process_user_input: bool = false

# Direct 6-DOF Input Registers (Pre-allocated for Zero Runtime Heap Allocations)
# thrust_input: (x: strafe right/left, y: vertical up/down, z: forward/reverse)
var thrust_input: Vector3 = Vector3.ZERO
# torque_input: (x: pitch up/down, y: yaw left/right, z: roll left/right)
var torque_input: Vector3 = Vector3.ZERO

# Pre-allocated Working Vectors (guarantees 0 heap allocations per physics frame)
var _thrust_local: Vector3 = Vector3.ZERO
var _thrust_world: Vector3 = Vector3.ZERO
var _torque_local: Vector3 = Vector3.ZERO
var _torque_world: Vector3 = Vector3.ZERO
var _drag_force: Vector3 = Vector3.ZERO
var _gravity_force: Vector3 = Vector3.ZERO
var _net_force: Vector3 = Vector3.ZERO
var _ship_vel: Vector3 = Vector3.ZERO

# Double-Rebase Protection (Engine frame, offset, and result origin deduplication)
var last_rebase_frame: int = -1
var last_rebase_offset: Vector3 = Vector3.ZERO
var _last_rebase_result_origin: Vector3 = Vector3(INF, INF, INF)

func _ready() -> void:
	# Disable global flat gravity; flight governed purely by thrusters and atmospheric drag
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.0

func _physics_process(_delta: float) -> void:
	if process_user_input:
		_sample_user_input()
	
	_apply_flight_forces()

func _apply_flight_forces() -> void:
	var center: Vector3 = get_planet_center()
	var radius: float = get_planet_radius()
	var pos: Vector3 = global_position if is_inside_tree() else position
	var alt: float = AtmosphereMath.get_altitude(pos, center, radius)
	var rho: float = AtmosphereMath.get_air_density(alt, atmosphere_ceiling, surface_air_density)
	
	_ship_vel = linear_velocity
	_drag_force = AtmosphereMath.calculate_drag_force(
		_ship_vel, rho, drag_coefficient, cross_sectional_area
	)
	
	if enable_planetary_gravity:
		var grav_accel: Vector3 = AtmosphereMath.calculate_gravity_acceleration(
			pos, center, radius, surface_gravity
		)
		_gravity_force = grav_accel * mass
	else:
		_gravity_force = Vector3.ZERO
	
	# Assemble local thrust forces
	# Local forward is -Z in Godot right-handed space; reverse is +Z
	_thrust_local.x = thrust_input.x * strafe_thrust
	_thrust_local.y = thrust_input.y * vertical_thrust
	_thrust_local.z = -thrust_input.z * (forward_thrust if thrust_input.z >= 0.0 else reverse_thrust)
	
	# Project thrust into world coordinates and apply net force (thrust + atmospheric drag + gravity)
	var ship_basis: Basis = global_transform.basis if is_inside_tree() else transform.basis
	_thrust_world = ship_basis * _thrust_local
	_net_force = _thrust_world + _drag_force + _gravity_force
	apply_central_force(_net_force)
	
	# Assemble local torques (x: pitch, y: yaw, z: roll)
	_torque_local.x = torque_input.x * pitch_torque
	_torque_local.y = torque_input.y * yaw_torque
	_torque_local.z = torque_input.z * roll_torque
	
	# Project torque into world coordinates and apply
	_torque_world = ship_basis * _torque_local
	apply_torque(_torque_world)

## Optional sampling of InputMap actions if defined in project settings
func _sample_user_input() -> void:
	if not InputMap.has_action("fly_forward"):
		return
	thrust_input.z = Input.get_axis("fly_backward", "fly_forward")
	thrust_input.x = Input.get_axis("fly_left", "fly_right")
	thrust_input.y = Input.get_axis("fly_down", "fly_up")
	torque_input.x = Input.get_axis("fly_pitch_down", "fly_pitch_up")
	torque_input.y = Input.get_axis("fly_yaw_right", "fly_yaw_left")
	torque_input.z = Input.get_axis("fly_roll_right", "fly_roll_left")

## Sets the 3-axis thrust input vector: (strafe, vertical, forward/reverse)
func set_thrust_input(val: Vector3) -> void:
	thrust_input = val

## Sets the 3-axis torque input vector: (pitch, yaw, roll)
func set_torque_input(val: Vector3) -> void:
	torque_input = val

## Rebase origin handler preserving exact linear and angular velocities with double-rebase guard
func rebase_origin(offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	
	var in_tree: bool = is_inside_tree()
	var current_origin: Vector3 = global_position if in_tree else position
	var current_frame: int = Engine.get_physics_frames()
	if current_frame == last_rebase_frame and offset == last_rebase_offset and current_origin == _last_rebase_result_origin:
		return
	
	last_rebase_frame = current_frame
	last_rebase_offset = offset
	
	var v_saved: Vector3 = linear_velocity
	var w_saved: Vector3 = angular_velocity
	var was_sleeping: bool = sleeping
	var rid: RID = get_rid()
	var t: Transform3D = global_transform if in_tree else transform
	t.origin -= offset
	_last_rebase_result_origin = t.origin
	
	if in_tree:
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v_saved)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, w_saved)
		if was_sleeping:
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, true)
		global_transform = t
		if has_method("reset_physics_interpolation"):
			reset_physics_interpolation()
	else:
		transform = t
	
	linear_velocity = v_saved
	angular_velocity = w_saved
	
	if not is_instance_valid(planet_manager):
		planet_position -= offset

func get_planet_center() -> Vector3:
	if is_instance_valid(planet_manager):
		if "planet_center_offset" in planet_manager:
			return planet_manager.planet_center_offset
		if planet_manager is Node3D:
			return planet_manager.global_position if planet_manager.is_inside_tree() else planet_manager.position
	return planet_position

func get_planet_radius() -> float:
	if is_instance_valid(planet_manager) and "planet_radius" in planet_manager:
		return planet_manager.planet_radius
	return planet_radius

func get_current_altitude() -> float:
	var pos: Vector3 = global_position if is_inside_tree() else position
	return AtmosphereMath.get_altitude(pos, get_planet_center(), get_planet_radius())

func get_current_density() -> float:
	return AtmosphereMath.get_air_density(get_current_altitude(), atmosphere_ceiling, surface_air_density)

func get_current_drag() -> Vector3:
	return _drag_force

func get_current_gravity() -> Vector3:
	return _gravity_force

func get_current_gravity_acceleration() -> Vector3:
	return _gravity_force / mass if mass > 0.0 else Vector3.ZERO

