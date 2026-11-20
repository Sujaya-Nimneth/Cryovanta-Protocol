class_name FlightInputBindings
extends RefCounted

## Idempotent default InputMap registration for the 6-DOF flight cockpit.

const ACTIONS: Array[StringName] = [
	&"fly_forward", &"fly_backward", &"fly_left", &"fly_right", &"fly_up", &"fly_down",
	&"fly_pitch_up", &"fly_pitch_down", &"fly_yaw_left", &"fly_yaw_right",
	&"fly_roll_left", &"fly_roll_right", &"fire_weapon", &"cycle_guidance_mode",
	&"rewind_flight", &"pause_sortie", &"restart_sortie"
]

static func ensure_default_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_ensure_key("fly_forward", KEY_W)
	_ensure_key("fly_backward", KEY_S)
	_ensure_key("fly_left", KEY_A)
	_ensure_key("fly_right", KEY_D)
	_ensure_key("fly_up", KEY_E)
	_ensure_key("fly_down", KEY_Q)
	_ensure_key("fly_pitch_up", KEY_I)
	_ensure_key("fly_pitch_down", KEY_K)
	_ensure_key("fly_yaw_left", KEY_J)
	_ensure_key("fly_yaw_right", KEY_L)
	_ensure_key("fly_roll_left", KEY_U)
	_ensure_key("fly_roll_right", KEY_O)
	_ensure_key("fire_weapon", KEY_SPACE)
	_ensure_key("cycle_guidance_mode", KEY_TAB)
	_ensure_key("rewind_flight", KEY_R)
	_ensure_key("pause_sortie", KEY_P)
	_ensure_key("pause_sortie", KEY_ESCAPE)
	_ensure_key("restart_sortie", KEY_BACKSPACE)
	_ensure_gamepad_defaults()

static func _ensure_gamepad_defaults() -> void:
	_ensure_joy_axis(&"fly_forward", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis(&"fly_backward", JOY_AXIS_LEFT_Y, 1.0)
	_ensure_joy_axis(&"fly_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis(&"fly_right", JOY_AXIS_LEFT_X, 1.0)
	_ensure_joy_button(&"fly_up", JOY_BUTTON_RIGHT_SHOULDER)
	_ensure_joy_button(&"fly_down", JOY_BUTTON_LEFT_SHOULDER)
	_ensure_joy_axis(&"fly_pitch_up", JOY_AXIS_RIGHT_Y, -1.0)
	_ensure_joy_axis(&"fly_pitch_down", JOY_AXIS_RIGHT_Y, 1.0)
	_ensure_joy_axis(&"fly_yaw_left", JOY_AXIS_RIGHT_X, -1.0)
	_ensure_joy_axis(&"fly_yaw_right", JOY_AXIS_RIGHT_X, 1.0)
	_ensure_joy_button(&"fly_roll_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_joy_button(&"fly_roll_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy_button(&"fire_weapon", JOY_BUTTON_A)
	_ensure_joy_axis(&"fire_weapon", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_ensure_joy_button(&"cycle_guidance_mode", JOY_BUTTON_Y)
	_ensure_joy_button(&"rewind_flight", JOY_BUTTON_X)
	_ensure_joy_button(&"pause_sortie", JOY_BUTTON_START)
	_ensure_joy_button(&"restart_sortie", JOY_BUTTON_BACK)

static func _ensure_key(action: StringName, keycode: Key) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)

static func _ensure_joy_button(action: StringName, button: JoyButton) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return
	var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
	joy_event.button_index = button
	InputMap.action_add_event(action, joy_event)

static func _ensure_joy_axis(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, axis_value):
			return
	var axis_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	axis_event.axis = axis
	axis_event.axis_value = axis_value
	InputMap.action_add_event(action, axis_event)
