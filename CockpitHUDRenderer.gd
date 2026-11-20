class_name CockpitHUDRenderer
extends RefCounted

## Zero-allocation CanvasItem HUD drawing delegate.
## Renders telemetry, boresight, GPWS banners, mission pips, and touch sticks.

const STR_ALT: String = "ALT"
const STR_RAD: String = "RAD"
const STR_VS: String = "V/S"
const STR_SPD: String = "SPD"
const STR_G: String = "G"
const STR_THR: String = "THR"
const STR_HULL: String = "HULL"
const STR_FUEL: String = "FUEL"
const STR_BAT: String = "BAT"
const STR_GEAR: String = "GEAR"
const STR_WPN: String = "WPN"

const STR_CAUTION: String = "[!] CAUTION - TERRAIN"
const STR_CAUTION_TRAFFIC: String = "[!] CAUTION - TRAFFIC"
const STR_PULL_UP: String = "[!!] PULL UP - TERRAIN"
const STR_OVERHEAT: String = "OVERHEAT"
const STR_PAUSED: String = "SORTIE PAUSED [P/ESC RESUME | BKSP RESTART]"
const STR_COMPLETE_BANNER: String = "MISSION COMPLETE [BKSP NEW SORTIE]"
const STR_FAILED_BANNER: String = "MISSION FAILED [R REWIND | BKSP RESTART]"
const MODE_NAMES: Array[String] = ["MANUAL", "SAS HOLD", "RADIAL UP", "RETRO", "HOVER", "SOFT LAND", "PROGRADE", "CIRCULARIZE", "INTERCEPT"]

const STR_STAGE_CRUISE: String = "MISSION: CRUISE"
const STR_STAGE_RECON: String = "MISSION: RECON"
const STR_STAGE_INTERCEPT: String = "MISSION: INTERCEPT"
const STR_STAGE_LANDING: String = "MISSION: LANDING"
const STR_STAGE_COMPLETE: String = "MISSION: COMPLETE"
const STR_STAGE_FAILED: String = "MISSION: FAILED"

const STR_LOCK_CLEAR: String = "LOCK"
const STR_LOCK_OCCLUDED: String = "OCCLUDED"
const STR_TOUCH_MODE: String = "MODE"
const STR_TOUCH_FIRE: String = "FIRE"

static func render_cockpit(surface: Control, hud: CockpitHUD, camera: Camera3D) -> void:
	if surface == null or hud == null:
		return
	hud._viewport_size = surface.size
	hud.last_drawn_target_reticles = 0
	hud.last_drawn_thermal_bars = 0
	hud.last_drawn_waypoint_markers = 0

	_render_telemetry_panel(surface, hud)
	_render_boresight(surface, hud._viewport_size * 0.5, hud._line_color)
	_render_gpws_banner(surface, hud)
	_render_mission_panel(surface, hud)
	_render_trajectory(surface, hud, camera)
	_render_targets(surface, hud, camera)
	_render_waypoints(surface, hud, camera)
	_render_touch_overlay(surface, hud)

static func _render_telemetry_panel(surface: Control, hud: CockpitHUD) -> void:
	var margin: float = 22.0
	var pw: float = minf(310.0, hud._viewport_size.x * 0.42)
	surface.draw_rect(Rect2(Vector2(margin, margin), Vector2(pw, MobileTouchLayout.PANEL_HEIGHT)), hud._panel_color)
	surface.draw_line(Vector2(margin, margin), Vector2(margin + pw, margin), hud._line_color, 2.0)

	var font: Font = ThemeDB.fallback_font
	var bx: float = margin + 46.0
	var bw: float = pw - 122.0
	var rx: float = bx + bw + 6.0
	var y: float = margin + 12.0

	_draw_labeled_bar(surface, font, STR_ALT, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(hud.displayed_altitude / 20000.0, 0.0, 1.0), hud._line_color)
	surface.draw_string(font, Vector2(rx, y + 7.0), hud.text_altitude, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, hud._line_color)
	y += 15.0
	_draw_labeled_bar(surface, font, STR_RAD, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(hud.displayed_radar_altitude / 5000.0, 0.0, 1.0), hud._trajectory_color)
	surface.draw_string(font, Vector2(rx, y + 7.0), hud.text_radar_alt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, hud._trajectory_color)
	y += 15.0
	_draw_labeled_bar(surface, font, STR_VS, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(absf(hud.displayed_vertical_speed) / 100.0, 0.0, 1.0), hud._warning_color)
	surface.draw_string(font, Vector2(rx, y + 7.0), hud.text_vs, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, hud._warning_color)
	y += 15.0
	_draw_labeled_bar(surface, font, STR_SPD, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(hud.displayed_horizontal_speed / 2000.0, 0.0, 1.0), hud._line_color)
	surface.draw_string(font, Vector2(rx, y + 7.0), hud.text_spd, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, hud._line_color)
	y += 15.0
	_draw_labeled_bar(surface, font, STR_G, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(hud.displayed_g_load / 10.0, 0.0, 1.0), hud._warning_color)
	surface.draw_string(font, Vector2(rx, y + 7.0), hud.text_g_load, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, hud._warning_color)
	y += 15.0
	_draw_labeled_bar(surface, font, STR_THR, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(hud.displayed_thrust, 0.0, 1.0), hud._trajectory_color)
	y += 15.0

	var half_bw: float = (bw - 8.0) * 0.5
	_draw_labeled_bar(surface, font, STR_HULL, Vector2(margin + 10.0, y), Vector2(bx, y), half_bw, 7.0,
		clampf(hud.displayed_hull_integrity / 100.0, 0.0, 1.0), hud._line_color)
	hud.last_drawn_thermal_bars = 1
	draw_bar(surface, Vector2(bx + half_bw + 6.0, y), half_bw, 7.0,
		clampf(hud.displayed_heat_load, 0.0, 1.0), hud._warning_color)
	hud.last_drawn_thermal_bars += 1
	y += 15.0

	_draw_labeled_bar(surface, font, STR_FUEL, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(hud.displayed_fuel_fraction, 0.0, 1.0), hud._line_color)
	surface.draw_string(font, Vector2(rx, y + 7.0), hud.text_fuel, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, hud._line_color)
	y += 15.0
	_draw_labeled_bar(surface, font, STR_BAT, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(hud.displayed_battery_fraction, 0.0, 1.0), hud._trajectory_color)
	y += 15.0
	_draw_labeled_bar(surface, font, STR_GEAR, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(hud.displayed_gear_progress, 0.0, 1.0), hud._line_color)
	y += 15.0
	var wpn_hot: bool = hud.displayed_weapon_overheated or hud.displayed_weapon_heat >= 1.0
	_draw_labeled_bar(surface, font, STR_WPN, Vector2(margin + 10.0, y), Vector2(bx, y), bw, 7.0,
		clampf(hud.displayed_weapon_heat, 0.0, 1.0), hud._warning_color if wpn_hot else hud._trajectory_color)
	if hud.displayed_weapon_overheated:
		surface.draw_string(font, Vector2(rx, y + 7.0), STR_OVERHEAT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, hud._warning_color)
	y += 17.0

	var mode_slot: int = clampi(hud.displayed_mode, 0, 8)
	surface.draw_rect(Rect2(Vector2(margin + 10.0, y), Vector2(10.0, 10.0)), hud._line_color)
	surface.draw_string(font, Vector2(margin + 26.0, y + 9.0), MODE_NAMES[mode_slot], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, hud._line_color)

static func _draw_labeled_bar(surface: Control, font: Font, label: String, lp: Vector2, bp: Vector2, w: float, h: float, fill: float, color: Color) -> void:
	surface.draw_string(font, Vector2(lp.x, lp.y + 7.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, color)
	draw_bar(surface, bp, w, h, fill, color)

static func draw_bar(surface: Control, pos: Vector2, width: float, height: float, fill: float, color: Color) -> void:
	surface.draw_rect(Rect2(pos, Vector2(width, height)), Color(0.04, 0.12, 0.14, 0.8))
	surface.draw_rect(Rect2(pos, Vector2(width * fill, height)), color)

static func _render_boresight(surface: Control, center: Vector2, color: Color) -> void:
	surface.draw_circle(center, 2.0, color)
	surface.draw_line(Vector2(center.x - 14.0, center.y), Vector2(center.x - 5.0, center.y), color, 1.5)
	surface.draw_line(Vector2(center.x + 5.0, center.y), Vector2(center.x + 14.0, center.y), color, 1.5)
	surface.draw_line(Vector2(center.x, center.y - 14.0), Vector2(center.x, center.y - 5.0), color, 1.5)
	surface.draw_line(Vector2(center.x, center.y + 5.0), Vector2(center.x, center.y + 14.0), color, 1.5)

static func _render_gpws_banner(surface: Control, hud: CockpitHUD) -> void:
	var font: Font = ThemeDB.fallback_font
	var cx: float = hud._viewport_size.x * 0.5
	if hud.displayed_proximity_alert == 1:
		var r := Rect2(Vector2(cx - 95.0, 126.0), Vector2(190.0, 26.0))
		var msg: String = STR_CAUTION_TRAFFIC if hud.displayed_traffic_alert else STR_CAUTION
		surface.draw_rect(r, Color(0.25, 0.12, 0.02, 0.85))
		surface.draw_rect(r, Color(1.0, 0.55, 0.1, 0.95), false, 2.0)
		surface.draw_string(font, Vector2(cx - 72.0, 144.0), msg, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 11, Color(1.0, 0.7, 0.2, 1.0))
	elif hud.displayed_proximity_alert == 2:
		var r := Rect2(Vector2(cx - 95.0, 126.0), Vector2(190.0, 28.0))
		surface.draw_rect(r, Color(0.4, 0.03, 0.03, 0.9))
		surface.draw_rect(r, Color(1.0, 0.15, 0.15, 1.0), false, 2.5)
		surface.draw_string(font, Vector2(cx - 70.0, 145.0), STR_PULL_UP, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 12, Color(1.0, 0.25, 0.25, 1.0))
	var state_msg: String = STR_PAUSED if hud.displayed_paused else (STR_COMPLETE_BANNER if hud.displayed_mission_stage == 4 else (STR_FAILED_BANNER if hud.displayed_mission_stage == 5 else ""))
	if state_msg != "":
		var sr := Rect2(Vector2(cx - 170.0, 160.0), Vector2(340.0, 26.0))
		surface.draw_rect(sr, hud._panel_color)
		surface.draw_rect(sr, hud._line_color, false, 1.5)
		surface.draw_string(font, Vector2(cx - 160.0, 178.0), state_msg, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 11, hud._line_color)

static func _render_mission_panel(surface: Control, hud: CockpitHUD) -> void:
	var pw: float = 180.0
	var px: float = hud._viewport_size.x - pw - 22.0
	surface.draw_rect(Rect2(Vector2(px, 22.0), Vector2(pw, 48.0)), hud._panel_color)
	surface.draw_line(Vector2(px, 22.0), Vector2(px + pw, 22.0), hud._line_color, 2.0)

	var stage_str: String = STR_STAGE_CRUISE
	match hud.displayed_mission_stage:
		1: stage_str = STR_STAGE_RECON
		2: stage_str = STR_STAGE_INTERCEPT
		3: stage_str = STR_STAGE_LANDING
		4: stage_str = STR_STAGE_COMPLETE
		5: stage_str = STR_STAGE_FAILED
	surface.draw_string(ThemeDB.fallback_font, Vector2(px + 8.0, 39.0), stage_str, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, hud._line_color)
	surface.draw_string(ThemeDB.fallback_font, Vector2(px + 8.0, 58.0), hud.text_score, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, hud._warning_color)

static func _render_trajectory(surface: Control, hud: CockpitHUD, camera: Camera3D) -> void:
	if camera == null or hud.trajectory_count < 2:
		return
	var index: int = 0
	while index < hud.trajectory_count:
		if camera.is_position_behind(hud.trajectory_points[index]):
			hud._projected_valid[index] = 0
		else:
			hud._projected_points[index] = camera.unproject_position(hud.trajectory_points[index])
			hud._projected_valid[index] = 1
		index += 1
	index = 1
	while index < hud.trajectory_count:
		if hud._projected_valid[index - 1] != 0 and hud._projected_valid[index] != 0:
			surface.draw_line(hud._projected_points[index - 1], hud._projected_points[index], hud._trajectory_color, 1.5)
		index += 1

static func _render_targets(surface: Control, hud: CockpitHUD, camera: Camera3D) -> void:
	if hud.locked_target_id < 0 or camera == null or not camera.is_inside_tree():
		return
	if not camera.is_position_behind(hud.locked_target_pos):
		var t_screen: Vector2 = camera.unproject_position(hud.locked_target_pos)
		var box := Rect2(t_screen - Vector2(14.0, 14.0), Vector2(28.0, 28.0))
		if hud.displayed_target_los:
			surface.draw_rect(box, hud.hud_warning_color, false, 1.5)
			surface.draw_string(ThemeDB.fallback_font, t_screen + Vector2(16.0, 4.0), STR_LOCK_CLEAR, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, hud.hud_warning_color)
		else:
			surface.draw_rect(box, Color(1.0, 0.25, 0.25, 0.65), false, 1.5)
			surface.draw_line(box.position, box.position + box.size, Color(1.0, 0.25, 0.25, 0.5), 1.0)
			surface.draw_string(ThemeDB.fallback_font, t_screen + Vector2(16.0, 4.0), STR_LOCK_OCCLUDED, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(1.0, 0.25, 0.25, 0.8))
		hud.last_drawn_target_reticles += 1
	if not camera.is_position_behind(hud.locked_lead_pos):
		var l_screen: Vector2 = camera.unproject_position(hud.locked_lead_pos)
		surface.draw_arc(l_screen, 8.0, 0.0, TAU, 12, hud.hud_alert_color, 1.5)
		hud.last_drawn_target_reticles += 1

static func _render_waypoints(surface: Control, hud: CockpitHUD, camera: Camera3D) -> void:
	if hud.active_waypoint_id < 0 or camera == null or not camera.is_inside_tree() or camera.is_position_behind(hud.active_waypoint_pos):
		return
	var wp_screen: Vector2 = camera.unproject_position(hud.active_waypoint_pos)
	var top: Vector2 = wp_screen + Vector2(0.0, -12.0)
	var right: Vector2 = wp_screen + Vector2(12.0, 0.0)
	var bottom: Vector2 = wp_screen + Vector2(0.0, 12.0)
	var left: Vector2 = wp_screen + Vector2(-12.0, 0.0)
	surface.draw_line(top, right, hud._line_color, 1.5)
	surface.draw_line(right, bottom, hud._line_color, 1.5)
	surface.draw_line(bottom, left, hud._line_color, 1.5)
	surface.draw_line(left, top, hud._line_color, 1.5)
	hud.last_drawn_waypoint_markers = 1

static func _render_touch_overlay(surface: Control, hud: CockpitHUD) -> void:
	MobileTouchLayout.render(surface, hud)
