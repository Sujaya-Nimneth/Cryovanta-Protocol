class_name MobileTouchLayout
extends RefCounted

const ACTION_MODE: int = 0
const ACTION_REWIND: int = 1
const ACTION_FIRE: int = 2
const EDGE_WIDTH: float = 76.0
const EDGE_MARGIN: float = 12.0
const STICK_MARGIN: float = 130.0
const PANEL_HEIGHT: float = 214.0
const PANEL_MARGIN: float = 22.0

const LABEL_MODE: String = "MODE"
const LABEL_REWIND: String = "REWIND"
const LABEL_FIRE: String = "FIRE"
const LABEL_HEAVE: String = "HEAVE"
const LABEL_ROLL: String = "ROLL"
const LABEL_MOVE: String = "MOVE"
const LABEL_ATTITUDE: String = "ATTITUDE"

const COLOR_ACTIVE: Color = Color(0.2, 0.95, 0.86, 0.85)
const COLOR_IDLE: Color = Color(0.2, 0.95, 0.86, 0.35)
const COLOR_FIRE: Color = Color(1.0, 0.48, 0.22, 0.75)
const COLOR_PANEL: Color = Color(0.02, 0.08, 0.1, 0.45)

static func top_band_height(viewport_size: Vector2) -> float:
	return clampf(viewport_size.y * 0.12, 64.0, 120.0)

static func action_rect(action: int, viewport_size: Vector2) -> Rect2:
	var height: float = top_band_height(viewport_size)
	var left: float = 0.0
	var width: float = viewport_size.x * 0.35
	if action == ACTION_REWIND:
		left = viewport_size.x * 0.35
		width = viewport_size.x * 0.3
	elif action == ACTION_FIRE:
		left = viewport_size.x * 0.65
		width = viewport_size.x * 0.35
	return Rect2(Vector2(left, 0.0), Vector2(width, height))

static func action_at(pos: Vector2, viewport_size: Vector2) -> int:
	if pos.y > top_band_height(viewport_size):
		return -1
	if pos.x < viewport_size.x * 0.35:
		return ACTION_MODE
	if pos.x < viewport_size.x * 0.65:
		return ACTION_REWIND
	return ACTION_FIRE

static func heave_rect(viewport_size: Vector2) -> Rect2:
	var top: float = maxf(top_band_height(viewport_size) + 24.0, PANEL_HEIGHT + PANEL_MARGIN + 36.0)
	var bottom: float = viewport_size.y - 260.0
	return Rect2(Vector2(EDGE_MARGIN, top), Vector2(EDGE_WIDTH, maxf(bottom - top, 120.0)))

static func roll_rect(viewport_size: Vector2) -> Rect2:
	var rect: Rect2 = heave_rect(viewport_size)
	rect.position.x = viewport_size.x - EDGE_MARGIN - EDGE_WIDTH
	return rect

static func left_stick_origin(viewport_size: Vector2) -> Vector2:
	return Vector2(STICK_MARGIN, viewport_size.y - STICK_MARGIN)

static func right_stick_origin(viewport_size: Vector2) -> Vector2:
	return Vector2(viewport_size.x - STICK_MARGIN, viewport_size.y - STICK_MARGIN)

static func render(surface: Control, hud: CockpitHUD) -> void:
	if surface == null or hud == null or hud.touch_controller == null:
		return
	var viewport_size: Vector2 = hud._viewport_size
	var controller: MobileTouchController = hud.touch_controller
	var overlay: MobileTouchOverlay = controller.overlay
	var font: Font = ThemeDB.fallback_font
	_render_action(surface, font, action_rect(ACTION_MODE, viewport_size), LABEL_MODE, COLOR_IDLE)
	_render_action(surface, font, action_rect(ACTION_REWIND, viewport_size), LABEL_REWIND, COLOR_IDLE)
	_render_action(surface, font, action_rect(ACTION_FIRE, viewport_size), LABEL_FIRE, COLOR_FIRE)
	_render_slider(surface, font, heave_rect(viewport_size), LABEL_HEAVE, controller.vertical_axis,
		overlay != null and overlay.heave_touch_index != -1)
	_render_slider(surface, font, roll_rect(viewport_size), LABEL_ROLL, controller.roll_axis,
		overlay != null and overlay.roll_touch_index != -1)
	var radius: float = overlay.joystick_radius if overlay != null else 90.0
	var left_origin: Vector2 = left_stick_origin(viewport_size)
	if overlay != null and overlay.left_touch_index != -1:
		left_origin = overlay.left_origin
	var right_origin: Vector2 = right_stick_origin(viewport_size)
	if overlay != null and overlay.right_touch_index != -1:
		right_origin = overlay.right_origin
	_render_stick(surface, font, left_origin, radius, LABEL_MOVE,
		Vector2(controller.left_stick.x, -controller.left_stick.y), COLOR_IDLE)
	_render_stick(surface, font, right_origin, radius, LABEL_ATTITUDE,
		Vector2(controller.right_stick.x, -controller.right_stick.y), COLOR_IDLE)

static func consume_actions(sim: PlanetarySimulation) -> void:
	if sim.touch_controller == null or sim.touch_controller.overlay == null:
		return
	var overlay: MobileTouchOverlay = sim.touch_controller.overlay
	if overlay.cycle_mode_requested:
		overlay.cycle_mode_requested = false
		if is_instance_valid(sim.guidance):
			sim.guidance.set_mode((sim.guidance.mode + 1) % 9)
	if overlay.fire_requested:
		overlay.fire_requested = false
		if is_instance_valid(sim.weapon_system):
			sim.weapon_system.fire_projectile()
	if overlay.rewind_requested:
		overlay.rewind_requested = false
		LiveSortieBootstrap.trigger_rewind(sim)

static func _render_action(surface: Control, font: Font, rect: Rect2, label: String, color: Color) -> void:
	surface.draw_rect(rect, COLOR_PANEL)
	surface.draw_rect(rect, color, false, 1.5)
	surface.draw_string(font, rect.position + Vector2(12.0, rect.size.y * 0.5 + 6.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 16, color)

static func _render_slider(surface: Control, font: Font, rect: Rect2, label: String, value: float, active: bool) -> void:
	var color: Color = COLOR_ACTIVE if active else COLOR_IDLE
	surface.draw_rect(rect, COLOR_PANEL)
	surface.draw_rect(rect, color, false, 1.5)
	var center: Vector2 = rect.position + rect.size * 0.5
	surface.draw_line(Vector2(center.x, rect.position.y + 18.0),
		Vector2(center.x, rect.end.y - 18.0), color, 2.0)
	var knob_y: float = center.y - clampf(value, -1.0, 1.0) * rect.size.y * 0.4
	surface.draw_circle(Vector2(center.x, knob_y), 12.0, color)
	surface.draw_string(font, Vector2(rect.position.x, rect.position.y - 6.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x + 24.0, 13, color)

static func _render_stick(surface: Control, font: Font, origin: Vector2, radius: float, label: String, deflection: Vector2, color: Color) -> void:
	surface.draw_arc(origin, radius, 0.0, TAU, 24, color, 1.5)
	surface.draw_circle(origin + deflection * radius, 18.0, color)
	surface.draw_string(font, origin + Vector2(-radius, radius + 18.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, radius * 2.0, 13, color)
