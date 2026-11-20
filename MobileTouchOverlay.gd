class_name MobileTouchOverlay
extends RefCounted

## Allocation-free multi-touch router for the Android dual-stick overlay.

var left_touch_index: int = -1
var right_touch_index: int = -1
var heave_touch_index: int = -1
var roll_touch_index: int = -1
var left_origin: Vector2 = Vector2.ZERO
var right_origin: Vector2 = Vector2.ZERO
var heave_origin: Vector2 = Vector2.ZERO
var roll_origin: Vector2 = Vector2.ZERO
var joystick_radius: float = 90.0
var fire_requested: bool = false
var cycle_mode_requested: bool = false
var rewind_requested: bool = false

var _left_deflection: Vector2 = Vector2.ZERO
var _right_deflection: Vector2 = Vector2.ZERO
var _heave_deflection: float = 0.0
var _roll_deflection: float = 0.0

func reset(controller: MobileTouchController = null) -> void:
	left_touch_index = -1
	right_touch_index = -1
	heave_touch_index = -1
	roll_touch_index = -1
	left_origin = Vector2.ZERO
	right_origin = Vector2.ZERO
	heave_origin = Vector2.ZERO
	roll_origin = Vector2.ZERO
	_left_deflection = Vector2.ZERO
	_right_deflection = Vector2.ZERO
	_heave_deflection = 0.0
	_roll_deflection = 0.0
	fire_requested = false
	cycle_mode_requested = false
	rewind_requested = false
	if controller != null:
		controller.set_virtual_sticks(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
		controller.enabled = false

func handle_touch_point(
	pressed: bool,
	index: int,
	pos: Vector2,
	viewport_size: Vector2,
	controller: MobileTouchController
) -> void:
	if pressed:
		var action: int = MobileTouchLayout.action_at(pos, viewport_size)
		if action >= 0:
			if action == MobileTouchLayout.ACTION_FIRE:
				fire_requested = true
			elif action == MobileTouchLayout.ACTION_MODE:
				cycle_mode_requested = true
			else:
				rewind_requested = true
			return
		if controller != null:
			controller.enabled = true
		if MobileTouchLayout.heave_rect(viewport_size).has_point(pos) and heave_touch_index == -1:
			heave_touch_index = index
			heave_origin = pos
		elif MobileTouchLayout.roll_rect(viewport_size).has_point(pos) and roll_touch_index == -1:
			roll_touch_index = index
			roll_origin = pos
		elif pos.x < viewport_size.x * 0.5 and left_touch_index == -1:
			left_touch_index = index
			left_origin = pos
		elif pos.x >= viewport_size.x * 0.5 and right_touch_index == -1:
			right_touch_index = index
			right_origin = pos
		return

	if index == left_touch_index:
		left_touch_index = -1
		_left_deflection = Vector2.ZERO
	elif index == right_touch_index:
		right_touch_index = -1
		_right_deflection = Vector2.ZERO
	elif index == heave_touch_index:
		heave_touch_index = -1
		_heave_deflection = 0.0
	elif index == roll_touch_index:
		roll_touch_index = -1
		_roll_deflection = 0.0
	else:
		return
	_publish(controller)

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
	elif index == heave_touch_index:
		_heave_deflection = _axis_deflection(pos, heave_origin)
	elif index == roll_touch_index:
		_roll_deflection = _axis_deflection(pos, roll_origin)
	else:
		return
	_publish(controller)

func _publish(controller: MobileTouchController) -> void:
	if controller == null:
		return
	controller.enabled = left_touch_index != -1 or right_touch_index != -1 \
		or heave_touch_index != -1 or roll_touch_index != -1
	controller.set_virtual_sticks(_left_deflection, _right_deflection, _heave_deflection, _roll_deflection)

func _screen_deflection(pos: Vector2, origin: Vector2) -> Vector2:
	var raw: Vector2 = (pos - origin) / maxf(joystick_radius, 1.0)
	# Screen +Y is down; invert it so an upward drag becomes positive forward throttle.
	return Vector2(raw.x, -raw.y)

func _axis_deflection(pos: Vector2, origin: Vector2) -> float:
	return clampf((origin.y - pos.y) / maxf(joystick_radius, 1.0), -1.0, 1.0)
