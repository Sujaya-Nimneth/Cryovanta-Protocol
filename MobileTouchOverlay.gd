class_name MobileTouchOverlay
extends RefCounted

## Allocation-free multi-touch router for the Android dual-stick overlay.

var left_touch_index: int = -1
var right_touch_index: int = -1
var left_origin: Vector2 = Vector2.ZERO
var right_origin: Vector2 = Vector2.ZERO
var joystick_radius: float = 90.0
var fire_requested: bool = false
var cycle_mode_requested: bool = false

var _left_deflection: Vector2 = Vector2.ZERO
var _right_deflection: Vector2 = Vector2.ZERO

func reset(controller: MobileTouchController = null) -> void:
	left_touch_index = -1
	right_touch_index = -1
	left_origin = Vector2.ZERO
	right_origin = Vector2.ZERO
	_left_deflection = Vector2.ZERO
	_right_deflection = Vector2.ZERO
	fire_requested = false
	cycle_mode_requested = false
	if controller != null:
		controller.set_virtual_sticks(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)

func handle_touch_point(
	pressed: bool,
	index: int,
	pos: Vector2,
	viewport_size: Vector2,
	controller: MobileTouchController
) -> void:
	var half_x: float = maxf(viewport_size.x * 0.5, 1.0)
	var top_band: float = maxf(viewport_size.y * 0.2, 1.0)
	if pressed:
		if pos.y <= top_band:
			if pos.x >= half_x:
				fire_requested = true
			else:
				cycle_mode_requested = true
			return
		if controller != null:
			controller.enabled = true
		if pos.x < half_x and left_touch_index == -1:
			left_touch_index = index
			left_origin = pos
		elif pos.x >= half_x and right_touch_index == -1:
			right_touch_index = index
			right_origin = pos
		return

	if index == left_touch_index:
		left_touch_index = -1
		_left_deflection = Vector2.ZERO
		if controller != null:
			controller.set_virtual_sticks(Vector2.ZERO, _right_deflection, 0.0, 0.0)
	if index == right_touch_index:
		right_touch_index = -1
		_right_deflection = Vector2.ZERO
		if controller != null:
			controller.set_virtual_sticks(_left_deflection, Vector2.ZERO, 0.0, 0.0)

func handle_drag_point(
	index: int,
	pos: Vector2,
	controller: MobileTouchController
) -> void:
	if controller == null:
		return
	if index == left_touch_index:
		_left_deflection = _screen_deflection(pos, left_origin)
	elif index == right_touch_index:
		_right_deflection = _screen_deflection(pos, right_origin)
	else:
		return
	controller.set_virtual_sticks(_left_deflection, _right_deflection, 0.0, 0.0)

func _screen_deflection(pos: Vector2, origin: Vector2) -> Vector2:
	var raw: Vector2 = (pos - origin) / maxf(joystick_radius, 1.0)
	# Screen +Y is down; invert it so an upward drag is positive on both sticks.
	return Vector2(raw.x, -raw.y)
