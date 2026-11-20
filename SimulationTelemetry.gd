class_name SimulationTelemetry
extends RefCounted

## Zero-allocation flight and streaming telemetry sampled once per simulation tick.

var altitude_asl: float = 0.0
var radar_altitude_agl: float = 0.0
var vertical_speed: float = 0.0
var horizontal_speed: float = 0.0
var total_speed: float = 0.0
var air_density: float = 0.0
var drag_magnitude: float = 0.0
var gravity_magnitude: float = 0.0
var g_load: float = 0.0
var active_leaves: int = 0
var active_visuals: int = 0
var active_colliders: int = 0
var active_projectiles: int = 0
var active_targets: int = 0
var active_impacts: int = 0
var origin_sector: Vector3i = Vector3i.ZERO
var circular_orbit_speed: float = 0.0
var escape_speed: float = 0.0
var orbital_eccentricity: float = 0.0
var periapsis_altitude: float = 0.0
var apoapsis_altitude: float = 0.0
var specific_orbital_energy: float = 0.0
var surface_temperature_k: float = 250.0
var heat_shield_load: float = 0.0
var hull_integrity: float = 100.0
var ema_frame_ms: float = 8.0
var governor_split_scale: float = 2.0
var active_waypoints: int = 0
var completed_waypoints: int = 0
var waypoint_distance: float = 0.0
var targets_destroyed: int = 0
var combat_score: int = 0
var weapon_heat: float = 0.0
var weapon_overheated: bool = false
var mission_stage: int = 0
var recorded_samples: int = 0
var fuel_fraction: float = 1.0
var remaining_delta_v: float = 0.0
var proximity_alert: int = 0
var time_to_impact: float = INF
var wind_speed: float = 0.0
var battery_fraction: float = 1.0
var in_eclipse: bool = false
var power_brownout: bool = false
var gear_deploy_progress: float = 1.0
var weight_on_wheels: bool = false
var surface_clearance: float = INF
var has_terrain_contact: bool = false
var target_los_clear: bool = true
var waypoint_signal_strength: float = 0.0

var _radial_up: Vector3 = Vector3.UP
var _tangential_velocity: Vector3 = Vector3.ZERO
var _ship_position: Vector3 = Vector3.ZERO
var _planet_center: Vector3 = Vector3.ZERO
var _gravity_accel: Vector3 = Vector3.ZERO
var _net_force: Vector3 = Vector3.ZERO
var _origin_sector: Vector3i = Vector3i.ZERO
var _apsides: Vector2 = Vector2.ZERO
var _planet_radius: float = 100_000.0
var _surface_gravity: float = 9.81

func sample(sim: PlanetarySimulation, space_state: PhysicsDirectSpaceState3D = null) -> void:
	if sim == null or not is_instance_valid(sim.ship) or not is_instance_valid(sim.planet_manager):
		return
	_origin_sector = sim.floating_origin.origin_sector
	var ship: SpaceshipController = sim.ship
	_ship_position = ship.global_position if ship.is_inside_tree() else ship.position
	_planet_center = ship.get_planet_center()
	_planet_radius = ship.get_planet_radius()
	_surface_gravity = ship.surface_gravity
	_radial_up = _ship_position - _planet_center
	if _radial_up.length_squared() > 1e-12:
		_radial_up = _radial_up.normalized()
	else:
		_radial_up = Vector3.UP
	altitude_asl = ship.get_current_altitude()
	total_speed = ship.linear_velocity.length()
	vertical_speed = ship.linear_velocity.dot(_radial_up)
	_tangential_velocity = ship.linear_velocity - _radial_up * vertical_speed
	horizontal_speed = _tangential_velocity.length()
	air_density = ship.get_current_density()
	drag_magnitude = ship.get_current_drag().length()
	_gravity_accel = ship.get_current_gravity() / maxf(ship.mass, 0.001)
	gravity_magnitude = _gravity_accel.length()
	_net_force = ship.get_current_net_force() - ship.get_current_gravity()
	g_load = _net_force.length() / maxf(ship.mass * 9.80665, 0.001)
	if space_state != null and is_instance_valid(sim.weapon_system):
		radar_altitude_agl = sim.weapon_system.measure_radar_altitude(space_state, 5_000.0)
		var hit_ok: bool = sim.weapon_system.last_radar_hit
		surface_clearance = maxf(radar_altitude_agl - 2.0, 0.0) if hit_ok else INF
		has_terrain_contact = hit_ok and radar_altitude_agl <= 4.0
	else:
		radar_altitude_agl = altitude_asl
		surface_clearance = maxf(radar_altitude_agl - 2.0, 0.0)
		has_terrain_contact = radar_altitude_agl <= 4.0
	active_leaves = sim.planet_manager.chunk_pool.active_count
	active_visuals = sim.planet_streamer.get_active_visual_count()
	active_colliders = sim.planet_manager.collider_pool.active_count
	active_projectiles = sim.projectile_pool.active_count
	active_targets = sim.target_pool.active_count if is_instance_valid(sim.target_pool) else 0
	active_impacts = sim.impact_pool.active_count if is_instance_valid(sim.impact_pool) else 0
	origin_sector = _origin_sector
	circular_orbit_speed = OrbitalMechanics.get_circular_orbit_speed(
		_ship_position, _planet_center, _planet_radius, _surface_gravity
	)
	escape_speed = OrbitalMechanics.get_escape_speed(
		_ship_position, _planet_center, _planet_radius, _surface_gravity
	)
	orbital_eccentricity = OrbitalMechanics.get_eccentricity_vector(
		_ship_position, ship.linear_velocity, _planet_center, _planet_radius, _surface_gravity
	).length()
	_apsides = OrbitalMechanics.get_apsides_altitudes(
		_ship_position, ship.linear_velocity, _planet_center, _planet_radius, _surface_gravity
	)
	periapsis_altitude = _apsides.x
	apoapsis_altitude = _apsides.y
	specific_orbital_energy = OrbitalMechanics.get_specific_orbital_energy(
		_ship_position, ship.linear_velocity, _planet_center, _planet_radius, _surface_gravity
	)

