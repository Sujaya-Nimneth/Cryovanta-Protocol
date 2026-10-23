class_name MobileTouchController
extends RefCounted

## Allocation-free Android virtual dual-stick mapping for six-axis flight.

var enabled: bool = false
var deadzone: float = 0.1
var left_stick: Vector2 = Vector2.ZERO
var right_stick: Vector2 = Vector2.ZERO
var vertical_axis: float = 0.0
var roll_axis: float = 0.0
var thrust_output: Vector3 = Vector3.ZERO
var torque_output: Vector3 = Vector3.ZERO

func set_virtual_sticks(
	left: Vector2,
	right: Vector2,
	vertical: float = 0.0,
	roll: float = 0.0
) -> void:
	if not enabled:
		left_stick = Vector2.ZERO
		right_stick = Vector2.ZERO
		vertical_axis = 0.0
		roll_axis = 0.0
		thrust_output = Vector3.ZERO
		torque_output = Vector3.ZERO
		return
	left_stick = _apply_radial_deadzone(left)
	right_stick = _apply_radial_deadzone(right)
	vertical_axis = clampf(vertical, -1.0, 1.0)
	roll_axis = clampf(roll, -1.0, 1.0)
	thrust_output = Vector3(left_stick.x, vertical_axis, left_stick.y)
	torque_output = Vector3(right_stick.y, right_stick.x, roll_axis)

func apply_to_ship(ship: SpaceshipController) -> void:
	if not is_instance_valid(ship):
		return
	ship.set_thrust_input(thrust_output)
	ship.set_torque_input(torque_output)

func _apply_radial_deadzone(input: Vector2) -> Vector2:
	var magnitude: float = input.length()
	if magnitude <= deadzone:
		return Vector2.ZERO
	var filtered: float = (magnitude - deadzone) / maxf(1.0 - deadzone, 0.001)
	return input * (minf(filtered, 1.0) / magnitude)
