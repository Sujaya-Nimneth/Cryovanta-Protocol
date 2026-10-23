class_name CockpitHUD
extends CanvasLayer

## Zero-allocation cockpit overlay. Registers are fixed storage; drawing is pooled.

const TRAJECTORY_STEPS: int = 64

var displayed_altitude: float = 0.0
var displayed_radar_altitude: float = 0.0
var displayed_vertical_speed: float = 0.0
var displayed_horizontal_speed: float = 0.0
var displayed_g_load: float = 0.0
var displayed_apoapsis: float = 0.0
var displayed_periapsis: float = 0.0
var displayed_eccentricity: float = 0.0
var displayed_mode: int = 0
var trajectory_points: PackedVector3Array = PackedVector3Array()
var trajectory_count: int = 0
var locked_target_id: int = -1
var locked_target_pos: Vector3 = Vector3.ZERO
var locked_lead_pos: Vector3 = Vector3.ZERO

var _surface: Control = null
var _projected_points: PackedVector2Array = PackedVector2Array()
var _projected_valid: PackedByteArray = PackedByteArray()
var _ship_position: Vector3 = Vector3.ZERO
var _ship_velocity: Vector3 = Vector3.ZERO
var _planet_center: Vector3 = Vector3.ZERO
var _planet_radius: float = 100_000.0
var _surface_gravity: float = 9.81
var _panel_color: Color = Color(0.015, 0.05, 0.065, 0.82)
var _line_color: Color = Color(0.2, 0.95, 0.86, 0.9)
var _trajectory_color: Color = Color(0.38, 0.88, 1.0, 0.92)
var _warning_color: Color = Color(1.0, 0.48, 0.22, 0.95)
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)

func _init() -> void:
	layer = 20
	trajectory_points.resize(TRAJECTORY_STEPS)
	_projected_points.resize(TRAJECTORY_STEPS)
	_projected_valid.resize(TRAJECTORY_STEPS)
	_surface = Control.new()
	_surface.name = "CockpitSurface"
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.draw.connect(_draw_cockpit)
	add_child(_surface)

func update_hud(sim: PlanetarySimulation, predict_dt: float = 0.5) -> void:
	if sim == null or not is_instance_valid(sim.ship) or sim.telemetry == null:
		trajectory_count = 0
		return
	var telemetry: SimulationTelemetry = sim.telemetry
	var ship: SpaceshipController = sim.ship
	displayed_altitude = telemetry.altitude_asl
	displayed_radar_altitude = telemetry.radar_altitude_agl
	displayed_vertical_speed = telemetry.vertical_speed
	displayed_horizontal_speed = telemetry.horizontal_speed
	displayed_g_load = telemetry.g_load
	displayed_apoapsis = telemetry.apoapsis_altitude
	displayed_periapsis = telemetry.periapsis_altitude
	displayed_eccentricity = telemetry.orbital_eccentricity
	displayed_mode = sim.guidance.mode if is_instance_valid(sim.guidance) else 0
	_ship_position = ship.global_position if ship.is_inside_tree() else ship.position
	_ship_velocity = ship.linear_velocity
	_planet_center = ship.get_planet_center()
	_planet_radius = ship.get_planet_radius()
	_surface_gravity = ship.surface_gravity
	_update_target_lock(sim)
	trajectory_count = OrbitalMechanics.predict_trajectory(
		_ship_position,
		_ship_velocity,
		_planet_center,
		_planet_radius,
		_surface_gravity,
		maxf(predict_dt, 0.001),
		TRAJECTORY_STEPS,
		trajectory_points
	)
	_surface.queue_redraw()

func rebase_origin(offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	var index: int = 0
	while index < TRAJECTORY_STEPS:
		trajectory_points[index] -= offset
		index += 1
	_ship_position -= offset
	_planet_center -= offset
	if locked_target_id >= 0:
		locked_target_pos -= offset
		locked_lead_pos -= offset
	_surface.queue_redraw()

func _update_target_lock(sim: PlanetarySimulation) -> void:
	locked_target_id = -1
	if not is_instance_valid(sim.weapon_system) or not is_instance_valid(sim.target_pool):
		return
	var target_id: int = sim.weapon_system.locked_target_id
	var pool: Node = sim.target_pool
	if not "is_in_use" in pool or not "positions" in pool:
		return
	if target_id < 0 or target_id >= pool.is_in_use.size():
		return
	if target_id >= pool.positions.size() or not pool.is_in_use[target_id]:
		return
	locked_target_id = target_id
	locked_target_pos = pool.get_target_position(target_id) if pool.has_method(
		"get_target_position"
	) else pool.positions[target_id]
	var target_velocity: Vector3 = pool.get_target_velocity(target_id) if pool.has_method(
		"get_target_velocity"
	) else pool.velocities[target_id]
	locked_lead_pos = SpaceshipWeaponSystem.calculate_lead_position(
		_ship_position,
		_ship_velocity,
		locked_target_pos,
		target_velocity
	)

func _draw_cockpit() -> void:
	_viewport_size = _surface.size
	var margin: float = 22.0
	var panel_width: float = minf(300.0, _viewport_size.x * 0.42)
	_surface.draw_rect(
		Rect2(Vector2(margin, margin), Vector2(panel_width, 154.0)), _panel_color
	)
	_surface.draw_line(
		Vector2(margin, margin), Vector2(margin + panel_width, margin), _line_color, 2.0
	)
	_draw_bar(Vector2(margin + 14.0, margin + 22.0), panel_width - 28.0, 9.0,
		clampf(displayed_altitude / 20_000.0, 0.0, 1.0), _line_color)
	_draw_bar(Vector2(margin + 14.0, margin + 43.0), panel_width - 28.0, 9.0,
		clampf(displayed_radar_altitude / 5_000.0, 0.0, 1.0), _trajectory_color)
	_draw_bar(Vector2(margin + 14.0, margin + 64.0), panel_width - 28.0, 9.0,
		clampf(absf(displayed_vertical_speed) / 100.0, 0.0, 1.0), _warning_color)
	_draw_bar(Vector2(margin + 14.0, margin + 85.0), panel_width - 28.0, 9.0,
		clampf(displayed_horizontal_speed / 2_000.0, 0.0, 1.0), _line_color)
	_draw_bar(Vector2(margin + 14.0, margin + 106.0), panel_width - 28.0, 9.0,
		clampf(displayed_g_load / 10.0, 0.0, 1.0), _warning_color)
	var mode_slot: int = clampi(displayed_mode, 0, 7)
	_surface.draw_rect(
		Rect2(Vector2(margin + 14.0 + mode_slot * 20.0, margin + 127.0), Vector2(12.0, 12.0)),
		_line_color
	)
	_draw_trajectory()

func _draw_bar(position: Vector2, width: float, height: float, fill: float, color: Color) -> void:
	_surface.draw_rect(Rect2(position, Vector2(width, height)), Color(0.04, 0.12, 0.14, 0.8))
	_surface.draw_rect(Rect2(position, Vector2(width * fill, height)), color)

func _draw_trajectory() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or trajectory_count < 2:
		return
	var index: int = 0
	while index < trajectory_count:
		_projected_points[index] = camera.unproject_position(trajectory_points[index])
		_projected_valid[index] = 0 if camera.is_position_behind(trajectory_points[index]) else 1
		index += 1
	index = 1
	while index < trajectory_count:
		if _projected_valid[index - 1] != 0 and _projected_valid[index] != 0:
			_surface.draw_line(
				_projected_points[index - 1], _projected_points[index], _trajectory_color, 1.5
			)
		index += 1
