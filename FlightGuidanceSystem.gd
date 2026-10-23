class_name FlightGuidanceSystem
extends Node

## Zero-allocation 6-DOF stability augmentation and landing guidance.

const MODE_MANUAL: int = 0
const MODE_SAS_HOLD: int = 1
const MODE_RADIAL_UP: int = 2
const MODE_RETROGRADE: int = 3
const MODE_HOVER: int = 4
const MODE_SOFT_LAND: int = 5
const MODE_PROGRADE: int = 6
const MODE_ORBIT_CIRCULARIZE: int = 7
@export var ship: RigidBody3D = null
@export var weapon_system: Node = null
@export var planet_manager: Node = null
@export var mode: int = MODE_MANUAL
@export var target_altitude: float = 500.0
@export var sas_gain: float = 4.0
@export var attitude_gain: float = 2.8
@export var angular_damping: float = 2.2
@export var hover_altitude_gain: float = 0.035
@export var hover_speed_gain: float = 14.0
@export var tangential_damping: float = 1.4
@export var max_descent_decel: float = 8.0
@export var min_descent_speed: float = 0.4
@export var max_descent_speed: float = 30.0
@export var touchdown_margin: float = 2.0
@export var circularize_gain: float = 0.08
@export var circularize_tolerance: float = 0.05

var _ship_position: Vector3 = Vector3.ZERO
var _planet_center: Vector3 = Vector3.ZERO
var _radial_up: Vector3 = Vector3.UP
var _target_world: Vector3 = Vector3.FORWARD
var _target_local: Vector3 = Vector3.UP
var _axis_local: Vector3 = Vector3.ZERO
var _angular_local: Vector3 = Vector3.ZERO
var _linear_local: Vector3 = Vector3.ZERO
var _gravity: Vector3 = Vector3.ZERO
var _gravity_accel: Vector3 = Vector3.ZERO
var _torque_command: Vector3 = Vector3.ZERO
var _thrust_command: Vector3 = Vector3.ZERO
var _tangential_velocity: Vector3 = Vector3.ZERO
var _basis: Basis = Basis.IDENTITY
var _basis_inv: Basis = Basis.IDENTITY
var _altitude: float = 0.0
var _radial_speed: float = 0.0
var _target_radial_speed: float = 0.0
var _mass: float = 1.0
var _planet_radius: float = 100_000.0
var _surface_gravity: float = 9.81
var _delta_v: Vector3 = Vector3.ZERO
var _thrust_axis_limit: Vector3 = Vector3.ONE

func update_guidance(delta: float, space_state: PhysicsDirectSpaceState3D = null) -> void:
	if not is_instance_valid(ship):
		return
	_ship_position = ship.global_position if ship.is_inside_tree() else ship.position
	_planet_center = _get_planet_center()
	_radial_up = _ship_position - _planet_center
	if _radial_up.length_squared() < 1e-12:
		_radial_up = Vector3.UP
	else:
		_radial_up = _radial_up.normalized()
	_basis = ship.global_transform.basis if ship.is_inside_tree() else ship.transform.basis
	_basis_inv = _basis.inverse()
	_angular_local = _basis_inv * ship.angular_velocity
	_linear_local = _basis_inv * ship.linear_velocity
	_mass = maxf(ship.mass, 0.001)
	_planet_radius = ship.get_planet_radius()
	_surface_gravity = ship.surface_gravity
	_gravity = ship.get_current_gravity()
	_gravity_accel = _gravity / _mass
	match mode:
		MODE_SAS_HOLD:
			_apply_sas_hold()
		MODE_RADIAL_UP:
			_apply_attitude(_radial_up)
			_clear_thrust()
		MODE_RETROGRADE:
			_apply_retrograde()
		MODE_HOVER:
			_apply_hover(space_state, delta)
		MODE_SOFT_LAND:
			_apply_soft_land(space_state, delta)
		MODE_PROGRADE:
			_apply_prograde()
		MODE_ORBIT_CIRCULARIZE:
			_apply_orbit_circularize()
		_:
			_clear_commands()

func set_mode(new_mode: int) -> void:
	mode = clampi(new_mode, MODE_MANUAL, MODE_ORBIT_CIRCULARIZE)

func _apply_sas_hold() -> void:
	_torque_command = -_angular_local * sas_gain
	ship.set_torque_input(_torque_command.clamp(Vector3.ONE * -1.0, Vector3.ONE))
	_clear_thrust()

func _apply_retrograde() -> void:
	if ship.linear_velocity.length_squared() > 0.04:
		_target_world = -ship.linear_velocity.normalized()
		_apply_attitude_target(Vector3.FORWARD, _target_world)
	else:
		_apply_sas_hold()
	_clear_thrust()

func _apply_prograde() -> void:
	if ship.linear_velocity.length_squared() > 0.04:
		_target_world = ship.linear_velocity.normalized()
		_apply_attitude_target(Vector3.FORWARD, _target_world)
	else:
		_apply_sas_hold()
	_clear_thrust()

func _apply_orbit_circularize() -> void:
	_delta_v = OrbitalMechanics.calculate_circularization_dv(
		_ship_position, ship.linear_velocity, _planet_center, _planet_radius, _surface_gravity
	)
	if _delta_v.length() <= circularize_tolerance:
		_clear_commands()
		return
	_apply_attitude_target(Vector3.FORWARD, _delta_v.normalized())
	var local_accel: Vector3 = (_basis_inv * _delta_v) * _mass * circularize_gain
	_thrust_command.x = local_accel.x / maxf(ship.strafe_thrust, 0.001)
	_thrust_command.y = local_accel.y / maxf(ship.vertical_thrust, 0.001)
	var longitudinal_thrust: float = ship.forward_thrust if local_accel.z <= 0.0 else ship.reverse_thrust
	_thrust_command.z = -local_accel.z / maxf(longitudinal_thrust, 0.001)
	var command_scale: float = maxf(absf(_thrust_command.x), maxf(
		absf(_thrust_command.y), absf(_thrust_command.z)
	))
	if command_scale > 1.0:
		_thrust_command /= command_scale
	ship.set_thrust_input(_thrust_command)

func _apply_attitude(world_target: Vector3) -> void:
	_apply_attitude_target(Vector3.UP, world_target)

func _apply_attitude_target(local_axis: Vector3, world_target: Vector3) -> void:
	_target_local = _basis_inv * world_target
	if _target_local.length_squared() < 1e-12:
		_target_local = local_axis
	else:
		_target_local = _target_local.normalized()
	_axis_local = local_axis.cross(_target_local)
	_torque_command = _axis_local * attitude_gain - _angular_local * angular_damping
	ship.set_torque_input(_torque_command.clamp(Vector3.ONE * -1.0, Vector3.ONE))

func _apply_hover(space_state: PhysicsDirectSpaceState3D, _delta: float) -> void:
	_apply_attitude(_radial_up)
	_altitude = _measure_altitude(space_state)
	_radial_speed = ship.linear_velocity.dot(_radial_up)
	_target_radial_speed = clampf((target_altitude - _altitude) * hover_altitude_gain, -20.0, 20.0)
	var vertical_accel: float = (_target_radial_speed - _radial_speed) * hover_speed_gain
	_thrust_command.y = (vertical_accel - _gravity_accel.dot(_radial_up)) * _mass / maxf(ship.vertical_thrust, 1.0)
	_damp_tangential_velocity()
	ship.set_thrust_input(_thrust_command.clamp(Vector3.ONE * -1.0, Vector3.ONE))

func _apply_soft_land(space_state: PhysicsDirectSpaceState3D, _delta: float) -> void:
	_apply_attitude(_radial_up)
	_altitude = _measure_altitude(space_state)
	_radial_speed = ship.linear_velocity.dot(_radial_up)
	if _altitude > touchdown_margin:
		var clearance: float = maxf(_altitude - touchdown_margin, 0.0)
		_target_radial_speed = -clampf(
			sqrt(2.0 * max_descent_decel * clearance),
			min_descent_speed,
			max_descent_speed
		)
	else:
		_target_radial_speed = 0.0
	var vertical_accel: float = (_target_radial_speed - _radial_speed) * hover_speed_gain
	if _radial_speed < 0.0 and vertical_accel > 0.0:
		vertical_accel = minf(vertical_accel, -_radial_speed / maxf(_delta, 1e-6))
	var thrust_y: float = (vertical_accel - _gravity_accel.dot(_radial_up)) * _mass / maxf(ship.vertical_thrust, 1.0)
	_thrust_command.y = thrust_y
	_damp_tangential_velocity()
	ship.set_thrust_input(_thrust_command.clamp(Vector3.ONE * -1.0, Vector3.ONE))

func _damp_tangential_velocity() -> void:
	_tangential_velocity = ship.linear_velocity - _radial_up * _radial_speed
	if _tangential_velocity.length_squared() > 1e-8:
		_target_world = _basis_inv * (-_tangential_velocity.normalized())
		_thrust_command.x = _target_world.x * _tangential_velocity.length() * _mass * tangential_damping / maxf(ship.strafe_thrust, 1.0)
		var longitudinal_thrust: float = ship.forward_thrust if -_target_world.z >= 0.0 else ship.reverse_thrust
		_thrust_command.z = -_target_world.z * _tangential_velocity.length() * _mass * tangential_damping / maxf(longitudinal_thrust, 1.0)
	else:
		_thrust_command.x = 0.0
		_thrust_command.z = 0.0

func _measure_altitude(space_state: PhysicsDirectSpaceState3D) -> float:
	if space_state != null and is_instance_valid(weapon_system):
		var radar_altitude: float = weapon_system.measure_radar_altitude(space_state, 5_000.0)
		if radar_altitude < 4_999.0:
			return radar_altitude
	return ship.get_current_altitude()

func _clear_thrust() -> void:
	ship.set_thrust_input(Vector3.ZERO)

func _clear_commands() -> void:
	ship.set_thrust_input(Vector3.ZERO)
	ship.set_torque_input(Vector3.ZERO)

func _get_planet_center() -> Vector3:
	if is_instance_valid(planet_manager) and "planet_center_offset" in planet_manager:
		return planet_manager.planet_center_offset
	return ship.get_planet_center()
