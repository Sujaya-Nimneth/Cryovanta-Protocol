extends SceneTree

## Phase 5 headless verification for orbital mechanics, guidance, environment, and HUD.
## Run with: godot --headless -s test_phase5_orbital_hud_environment_headless.gd

const PLANET_RADIUS: float = 100_000.0
const SURFACE_GRAVITY: float = 9.81
const PLANET_CENTER: Vector3 = Vector3(0.0, -PLANET_RADIUS, 0.0)
const DT: float = 1.0 / 120.0

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 5 Headless Verification Suite (Tiers 1-5)")
	print("==================================================================")
	await process_frame
	_run_tier_1()
	await _run_tier_2()
	_run_tier_3()
	await _run_tier_4()
	await _run_tier_5()
	_print_summary()
	quit(0 if failed_assertions == 0 else 1)

func _start_test(test_name: String) -> void:
	current_test_name = test_name
	print("  [TEST] %s" % test_name)

func _assert(condition: bool, message: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("    [FAIL] %s: %s" % [current_test_name, message])

func _assert_int(actual: int, expected: int, message: String) -> void:
	_assert(actual == expected, "%s (expected %d, got %d)" % [message, expected, actual])

func _assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assert(absf(actual - expected) <= tolerance, "%s (expected %.8f, got %.8f)" % [
		message, expected, actual
	])

func _assert_vec3(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> void:
	_assert(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [
		message, str(expected), str(actual)
	])

func _print_summary() -> void:
	print("\n==================================================================")
	print("PHASE 5 TEST SUITE EXECUTION SUMMARY")
	print("==================================================================")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	print("==================================================================")
	if failed_assertions == 0:
		print("SUCCESS: All %d assertions passed with exit code 0!" % total_assertions)
	else:
		printerr("FAILURE: %d out of %d assertions failed!" % [
			failed_assertions, total_assertions
		])

func _state(altitude: float, speed: float) -> Array[Vector3]:
	return [
		Vector3(0.0, altitude, 0.0),
		Vector3(speed, 0.0, 0.0),
		PLANET_CENTER,
		Vector3(PLANET_RADIUS + altitude, 0.0, 0.0)
	]

func _eccentricity(
	position: Vector3, velocity: Vector3, planet_center: Vector3 = PLANET_CENTER
) -> float:
	return OrbitalMechanics.get_eccentricity_vector(
		position, velocity, planet_center, PLANET_RADIUS, SURFACE_GRAVITY
	).length()

func _make_ship(position: Vector3, velocity: Vector3) -> SpaceshipController:
	var ship: SpaceshipController = SpaceshipController.new()
	ship.planet_manager = null
	ship.planet_position = PLANET_CENTER
	ship.planet_radius = PLANET_RADIUS
	ship.surface_gravity = SURFACE_GRAVITY
	ship.atmosphere_ceiling = 10_000.0
	ship.enable_planetary_gravity = true
	ship.process_user_input = false
	ship.set_physics_process(false)
	ship.freeze = true
	ship.mass = 1_000.0
	var root: Window = get_root(); root.add_child(ship)
	ship.global_transform = Transform3D(Basis.IDENTITY, position)
	ship.linear_velocity = velocity
	return ship

func _step_orbit(ship: SpaceshipController, guidance: FlightGuidanceSystem, steps: int) -> void:
	for i in range(steps):
		guidance.update_guidance(DT)
		ship._apply_flight_forces()
		var thrust_local: Vector3 = Vector3(
			ship.thrust_input.x * ship.strafe_thrust,
			ship.thrust_input.y * ship.vertical_thrust,
			-ship.thrust_input.z * (
				ship.forward_thrust if ship.thrust_input.z >= 0.0 else ship.reverse_thrust
			)
		)
		var acceleration: Vector3 = AtmosphereMath.calculate_gravity_acceleration(
			ship.global_position, ship.get_planet_center(), ship.get_planet_radius(),
			ship.surface_gravity
		)
		acceleration += ship.global_transform.basis * thrust_local / ship.mass
		acceleration += ship.get_current_drag() / ship.mass
		ship.linear_velocity += acceleration * DT
		ship.global_position += ship.linear_velocity * DT
		var angular_accel: Vector3 = ship.global_transform.basis * (
			ship.torque_input * Vector3(ship.pitch_torque, ship.yaw_torque, ship.roll_torque)
		) / Vector3(2_000.0, 2_000.0, 3_000.0)
		ship.angular_velocity += angular_accel * DT
		if ship.angular_velocity.length_squared() > 1e-12:
			var rotation: Quaternion = ship.global_transform.basis.get_rotation_quaternion()
			var spin: Quaternion = Quaternion(
				ship.angular_velocity.normalized(), ship.angular_velocity.length() * DT
			)
			ship.global_transform.basis = Basis((spin * rotation).normalized())

func _run_tier_1() -> void:
	print("\n--- Tier 1: Keplerian Mechanics and Trajectory Prediction ---")
	_start_test("Tier 1.1: Circular and escape speed contracts")
	var state: Array[Vector3] = _state(500.0, 0.0)
	var mu: float = SURFACE_GRAVITY * PLANET_RADIUS * PLANET_RADIUS
	var radius: float = PLANET_RADIUS + 500.0
	var circular: float = OrbitalMechanics.get_circular_orbit_speed(
		state[0], PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	)
	var escape: float = OrbitalMechanics.get_escape_speed(
		state[0], PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	)
	_assert_approx(OrbitalMechanics.get_gravitational_parameter(PLANET_RADIUS, SURFACE_GRAVITY),
		mu, 1e-3, "Gravitational parameter")
	_assert_approx(circular, sqrt(mu / radius), 1e-9, "Circular orbit speed")
	_assert_approx(escape, sqrt(2.0) * circular, 1e-9, "Escape speed is sqrt(2) * circular")
	var surface_circular: float = OrbitalMechanics.get_circular_orbit_speed(
		PLANET_CENTER, PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	)
	_assert_approx(surface_circular, sqrt(mu / PLANET_RADIUS), 1e-9, "Radius clamp at surface")

	_start_test("Tier 1.2: Eccentricity, apsides, and circularization delta-v")
	var circular_state: Array[Vector3] = _state(500.0, circular)
	_assert_vec3(OrbitalMechanics.get_eccentricity_vector(
		circular_state[0], circular_state[1], PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	), Vector3.ZERO, 1e-7, "Circular eccentricity vector")
	var apsides: Vector2 = OrbitalMechanics.get_apsides_altitudes(
		circular_state[0], circular_state[1], PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	)
	_assert_approx(apsides.x, 500.0, 0.01, "Circular periapsis altitude")
	_assert_approx(apsides.y, 500.0, 0.01, "Circular apoapsis altitude")
	var ellipse: Array[Vector3] = _state(500.0, 1_150.0)
	var ellipse_apsides: Vector2 = OrbitalMechanics.get_apsides_altitudes(
		ellipse[0], ellipse[1], PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	)
	_assert(ellipse_apsides.x < 500.0 and ellipse_apsides.y > 500.0,
		"Apsides bracket the current altitude")
	var ellipse_energy: float = OrbitalMechanics.get_specific_orbital_energy(
		ellipse[0], ellipse[1], PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	)
	var semi_major_axis: float = -mu / (2.0 * ellipse_energy)
	var ellipse_e: float = _eccentricity(ellipse[0], ellipse[1])
	_assert_approx(ellipse_apsides.x, semi_major_axis * (1.0 - ellipse_e) - PLANET_RADIUS,
		0.01, "Analytic periapsis altitude")
	_assert_approx(ellipse_apsides.y, semi_major_axis * (1.0 + ellipse_e) - PLANET_RADIUS,
		0.01, "Analytic apoapsis altitude")
	var escape_state: Array[Vector3] = _state(500.0, escape * 1.01)
	_assert(is_inf(OrbitalMechanics.get_apsides_altitudes(
		escape_state[0], escape_state[1], PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	).y), "Hyperbolic apoapsis is infinite")
	var dv: Vector3 = OrbitalMechanics.calculate_circularization_dv(
		ellipse[0], ellipse[1], PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	)
	var tangent: Vector3 = (ellipse[1] - (ellipse[0] - PLANET_CENTER).normalized() * ellipse[1].dot(
		(ellipse[0] - PLANET_CENTER).normalized()
	)).normalized()
	_assert_vec3(dv, Vector3(circular - 1_150.0, 0.0, 0.0), 1e-6, "Prograde circularization delta-v")
	_assert_approx(dv.dot(tangent), -dv.length(), 1e-7, "Delta-v is local horizontal")
	_assert_approx(dv.dot((ellipse[0] - PLANET_CENTER).normalized()), 0.0, 1e-7,
		"Delta-v is local horizontal")
	var radial: Vector3 = (ellipse[0] - PLANET_CENTER).normalized()
	var stationary_dv: Vector3 = OrbitalMechanics.calculate_circularization_dv(
		ellipse[0], Vector3.ZERO, PLANET_CENTER, PLANET_RADIUS, SURFACE_GRAVITY
	)
	_assert(stationary_dv.length() > 0.0, "Stationary vessel receives a circularization burn")
	_assert_approx(stationary_dv.length(), circular, 1e-5,
		"Stationary circularization delta-v equals circular speed")
	_assert_approx(stationary_dv.dot(radial), 0.0, 1e-9,
		"Stationary circularization delta-v is horizontal")

	_start_test("Tier 1.3: 64-point fixed-buffer trajectory prediction")
	var trajectory: PackedVector3Array = PackedVector3Array()
	trajectory.resize(64)
	var count: int = OrbitalMechanics.predict_trajectory(
		circular_state[0], circular_state[1], PLANET_CENTER, PLANET_RADIUS,
		SURFACE_GRAVITY, 0.5, 64, trajectory
	)
	_assert_int(count, 64, "Predicted all 64 trajectory points")
	_assert(trajectory[0].distance_to(circular_state[0]) > 0.1, "First point advances the trajectory")
	for i in range(1, count):
		_assert(trajectory[i].distance_to(trajectory[i - 1]) > 0.0, "Trajectory point %d advances" % i)
	_assert_approx(AtmosphereMath.get_altitude(trajectory[63], PLANET_CENTER, PLANET_RADIUS),
		500.0, 1.0, "Velocity-Verlet prediction preserves orbit altitude")
	var small: PackedVector3Array = PackedVector3Array()
	small.resize(8)
	_assert_int(OrbitalMechanics.predict_trajectory(
		circular_state[0], circular_state[1], PLANET_CENTER, PLANET_RADIUS,
		SURFACE_GRAVITY, 0.5, 64, small
	), 8, "Prediction respects destination capacity")
	var impact_state: Array[Vector3] = _state(100.0, 0.0)
	var impact_count: int = OrbitalMechanics.predict_trajectory(
		impact_state[0], impact_state[1], PLANET_CENTER, PLANET_RADIUS,
		SURFACE_GRAVITY, 0.5, 64, trajectory
	)
	_assert(impact_count > 0 and impact_count < 64, "Surface impact stops prediction early")
	for i in range(128):
		count = OrbitalMechanics.predict_trajectory(
			circular_state[0], circular_state[1], PLANET_CENTER, PLANET_RADIUS,
			SURFACE_GRAVITY, 0.5, 64, trajectory
		)
	var before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		count = OrbitalMechanics.predict_trajectory(
			circular_state[0], circular_state[1], PLANET_CENTER, PLANET_RADIUS,
			SURFACE_GRAVITY, 0.5, 64, trajectory
		)
	var after: int = OS.get_static_memory_usage()
	_assert_int(count, 64, "Warm prediction remains full length")
	_assert(after - before <= 0, "Trajectory prediction has zero static memory growth (%d bytes)" % (
		after - before
	))

func _integrate_attitude(
	ship: SpaceshipController, guidance: FlightGuidanceSystem, steps: int
) -> void:
	for i in range(steps):
		guidance.update_guidance(DT)
		var angular_accel: Vector3 = ship.global_transform.basis * (
			ship.torque_input * Vector3(ship.pitch_torque, ship.yaw_torque, ship.roll_torque)
		) / Vector3(2_000.0, 2_000.0, 3_000.0)
		ship.angular_velocity += angular_accel * DT
		if ship.angular_velocity.length_squared() > 1e-12:
			var rotation: Quaternion = ship.global_transform.basis.get_rotation_quaternion()
			var spin: Quaternion = Quaternion(
				ship.angular_velocity.normalized(), ship.angular_velocity.length() * DT
			)
			ship.global_transform.basis = Basis((spin * rotation).normalized())

func _run_tier_2() -> void:
	print("\n--- Tier 2: Prograde and Circularization Guidance ---")
	_start_test("Tier 2.1: Prograde aligns forward and cuts thrust")
	var ship: SpaceshipController = _make_ship(Vector3(0.0, 500.0, 0.0), Vector3(140.0, 18.0, -65.0))
	var guidance: FlightGuidanceSystem = FlightGuidanceSystem.new()
	guidance.ship = ship
	guidance.set_physics_process(false)
	get_root().add_child(guidance)
	guidance.set_mode(FlightGuidanceSystem.MODE_PROGRADE)
	_integrate_attitude(ship, guidance, 720)
	var velocity_direction: Vector3 = ship.linear_velocity.normalized()
	var forward_alignment: float = (-ship.global_transform.basis.z).dot(velocity_direction)
	_assert(forward_alignment > 0.98, "Forward axis aligned prograde (%.6f)" % forward_alignment)
	_assert_vec3(ship.thrust_input, Vector3.ZERO, 1e-9, "Prograde mode applies zero thrust")
	_assert(ship.angular_velocity.length() < 0.08, "Prograde attitude settled")
	ship.linear_velocity = Vector3.ZERO
	ship.angular_velocity = Vector3(0.4, -0.3, 0.2)
	guidance.update_guidance(DT)
	_assert_vec3(ship.thrust_input, Vector3.ZERO, 1e-9, "Stationary prograde cuts thrust")
	_assert(ship.torque_input.length() > 0.0, "Stationary prograde falls back to SAS hold")
	guidance.free()
	ship.free()

	_start_test("Tier 2.2: Closed-loop circularization across a 2,000 m rebase")
	_dispose_planet_world()
	var planet: PlanetManager = PlanetManager.new()
	planet.max_lod = 1
	get_root().add_child(planet)
	planet.planet_center_offset = PLANET_CENTER
	ship = _make_ship(Vector3(0.0, 20_000.0, 0.0), Vector3(1_150.0, 0.0, 0.0))
	ship.planet_manager = planet
	ship.global_transform.basis = Basis.IDENTITY
	var origin: FloatingOrigin = FloatingOrigin.new()
	origin.player_node = ship
	origin.planet_manager = planet
	origin.set_physics_process(false)
	get_root().add_child(origin)
	guidance = FlightGuidanceSystem.new()
	guidance.ship = ship
	guidance.planet_manager = planet
	guidance.set_physics_process(false)
	get_root().add_child(guidance)
	guidance.set_mode(FlightGuidanceSystem.MODE_ORBIT_CIRCULARIZE)
	guidance.circularize_gain = 0.5
	var initial_e: float = _eccentricity(ship.global_position, ship.linear_velocity)
	_assert(initial_e > 0.15, "Initial elliptical/sub-orbital eccentricity exceeds 0.15")
	var rebase_offset: Vector3 = Vector3(2_000.0, 0.0, -500.0)
	for i in range(3_000):
		_step_orbit(ship, guidance, 1)
		if i == 900:
			var velocity_before: Vector3 = ship.linear_velocity
			var altitude_before: float = ship.get_current_altitude()
			origin.rebase(rebase_offset)
			_assert_vec3(ship.linear_velocity, velocity_before, 1e-5, "Circularization velocity continuous")
			_assert_approx(ship.get_current_altitude(), altitude_before, 1e-3, "Orbit altitude preserved")
	var final_e: float = _eccentricity(
		ship.global_position, ship.linear_velocity, ship.get_planet_center()
	)
	_assert(final_e < 0.01, "Circularization reduced eccentricity below 0.01 (got %.6f)" % final_e)
	_assert(guidance._delta_v.length() <= guidance.circularize_tolerance,
		"Circularization delta-v converged")
	_assert_vec3(ship.thrust_input, Vector3.ZERO, 1e-9, "Circularization cuts thrust on convergence")
	_assert(origin.origin_sector != Vector3i.ZERO or origin.accumulated_offset == rebase_offset,
		"FloatingOrigin recorded the 2,000 m rebase")
	origin.free()
	guidance.free()
	ship.free()
	planet.destroy()
	planet.free()

func _dispose_planet_world() -> void:
	for child in get_root().get_children():
		if child is PlanetManager:
			child.destroy()
			get_root().remove_child(child)
			child.free()

func _run_tier_3() -> void:
	print("\n--- Tier 3: Surface-to-Vacuum Planetary Environment ---")
	_start_test("Tier 3.1: Smooth atmospheric lighting and fog transition")
	var environment: PlanetaryEnvironment = PlanetaryEnvironment.new()
	get_root().add_child(environment)
	var ceiling: float = 10_000.0
	environment.update_environment(Vector3.ZERO, PLANET_CENTER, PLANET_RADIUS, ceiling)
	_assert_approx(environment.current_atmosphere_factor, 1.0, 1e-9, "Surface atmosphere factor")
	_assert(environment.current_fog_density > 0.0, "Surface fog is enabled")
	_assert(environment.environment.fog_enabled, "Surface environment fog enabled")
	_assert_approx(environment.sky_material.sky_energy_multiplier, 1.35, 1e-6, "Surface sky energy")
	var previous: float = environment.current_atmosphere_factor
	var monotonic: bool = true
	for i in range(1, 20):
		var altitude: float = ceiling * float(i) / 20.0
		environment.update_environment(
			Vector3(0.0, altitude, 0.0), PLANET_CENTER, PLANET_RADIUS, ceiling
		)
		if environment.current_atmosphere_factor > previous + 1e-9:
			monotonic = false
		previous = environment.current_atmosphere_factor
	_assert(monotonic, "Atmosphere factor decreases monotonically with altitude")
	environment.update_environment(
		Vector3(0.0, ceiling, 0.0), PLANET_CENTER, PLANET_RADIUS, ceiling
	)
	_assert_approx(environment.current_atmosphere_factor, 0.0, 1e-12, "Vacuum factor at ceiling")
	_assert_approx(environment.current_fog_density, 0.0, 1e-12, "Vacuum fog density at ceiling")
	_assert(not environment.environment.fog_enabled, "Fog disabled in vacuum")
	_assert_approx(environment.sky_material.sky_energy_multiplier, 2.4, 1e-6, "Vacuum sky energy")
	environment.update_environment(
		Vector3(0.0, ceiling + 5_000.0, 0.0), PLANET_CENTER, PLANET_RADIUS, ceiling
	)
	_assert_approx(environment.current_atmosphere_factor, 0.0, 1e-12, "Vacuum remains zero above ceiling")
	for i in range(64):
		environment.update_environment(Vector3(0.0, 4_000.0, 0.0), PLANET_CENTER,
			PLANET_RADIUS, ceiling)
	var before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		environment.update_environment(Vector3(0.0, 4_000.0, 0.0), PLANET_CENTER,
			PLANET_RADIUS, ceiling)
	var after: int = OS.get_static_memory_usage()
	_assert(after - before <= 0, "Environment updates have zero static memory growth (%d bytes)" % (
		after - before
	))
	environment.free()

func _instantiate_sim() -> Node:
	var packed: PackedScene = load("res://main.tscn")
	var sim: Node = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	sim.initial_altitude = 1_000.0
	get_root().add_child(sim)
	return sim

func _dispose_sim(sim: Node) -> void:
	if sim == null:
		return
	sim.destroy()
	if sim.get_parent() == get_root():
		get_root().remove_child(sim)
	sim.free()

func _run_tier_4() -> void:
	print("\n--- Tier 4: Input Bindings, HUD Synchronization, and Runtime Allocation ---")
	_start_test("Tier 4.1: Idempotent default InputMap actions")
	FlightInputBindings.ensure_default_actions()
	var first_counts: Array[int] = []
	for action in FlightInputBindings.ACTIONS:
		_assert(InputMap.has_action(action), "InputMap registers %s" % action)
		first_counts.append(InputMap.action_get_events(action).size())
	FlightInputBindings.ensure_default_actions()
	for i in range(FlightInputBindings.ACTIONS.size()):
		_assert_int(InputMap.action_get_events(FlightInputBindings.ACTIONS[i]).size(),
			first_counts[i], "InputMap action %s is idempotent" % FlightInputBindings.ACTIONS[i])

	_start_test("Tier 4.2: HUD telemetry and 64-point trajectory synchronization")
	var sim: Node = _instantiate_sim()
	await process_frame
	_assert(sim.environment != null and sim.environment.get_parent() == sim,
		"PlanetaryEnvironment is wired")
	_assert(sim.hud != null and sim.hud.get_parent() == sim, "CockpitHUD is wired")
	_assert(sim.floating_origin.origin_rebased.is_connected(sim.hud.rebase_origin),
		"HUD listens to origin rebases")
	_assert_int(sim.hud.trajectory_points.size(), 64, "HUD preallocates 64 trajectory points")
	sim.planet_manager.max_lod = 1
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.ship.global_position = Vector3.ZERO
	sim.ship.linear_velocity = Vector3(985.0, 5.0, 25.0)
	sim.ship.angular_velocity = Vector3.ZERO
	sim.step_simulation(DT)
	_assert_approx(sim.hud.displayed_altitude, sim.telemetry.altitude_asl, 1e-9,
		"HUD altitude follows telemetry")
	_assert_approx(sim.hud.displayed_radar_altitude, sim.telemetry.radar_altitude_agl, 1e-9,
		"HUD radar altitude follows telemetry")
	_assert_approx(sim.hud.displayed_vertical_speed, sim.telemetry.vertical_speed, 1e-9,
		"HUD vertical speed follows telemetry")
	_assert_approx(sim.hud.displayed_horizontal_speed, sim.telemetry.horizontal_speed, 1e-9,
		"HUD horizontal speed follows telemetry")
	_assert_approx(sim.hud.displayed_g_load, sim.telemetry.g_load, 1e-9,
		"HUD G-load follows telemetry")
	_assert_approx(sim.hud.displayed_apoapsis, sim.telemetry.apoapsis_altitude, 1e-9,
		"HUD apoapsis follows telemetry")
	_assert_approx(sim.hud.displayed_periapsis, sim.telemetry.periapsis_altitude, 1e-9,
		"HUD periapsis follows telemetry")
	_assert_approx(sim.hud.displayed_eccentricity, sim.telemetry.orbital_eccentricity, 1e-9,
		"HUD eccentricity follows telemetry")
	_assert_int(sim.hud.displayed_mode, sim.guidance.mode, "HUD guidance mode follows autopilot")

	_start_test("Tier 4.2b: Manual input survives simulation stepping")
	sim.ship.global_position = Vector3.ZERO
	sim.ship.global_transform.basis = Basis.IDENTITY
	sim.ship.linear_velocity = Vector3.ZERO
	sim.ship.angular_velocity = Vector3.ZERO
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_MANUAL)
	sim.ship.set_thrust_input(Vector3(0.0, 0.0, 1.0))
	sim.step_simulation(DT)
	_assert_vec3(sim.ship.thrust_input, Vector3(0.0, 0.0, 1.0), 1e-9,
		"Manual thrust survives step_simulation")
	_assert(sim.ship.get_current_net_force().dot(-sim.ship.global_transform.basis.z) > 0.0,
		"Manual forward thrust accelerates the vessel")
	_assert(sim.hud.displayed_mode == FlightGuidanceSystem.MODE_MANUAL,
		"HUD reports manual guidance mode")
	_assert(sim.hud.trajectory_count > 1, "HUD populated the orbital trajectory")
	var previous_point: Vector3 = sim.hud.trajectory_points[0]
	var monotonic: bool = true
	for i in range(1, sim.hud.trajectory_count):
		if sim.hud.trajectory_points[i] == previous_point:
			monotonic = false
		previous_point = sim.hud.trajectory_points[i]
	_assert(monotonic, "HUD trajectory contains advancing points")
	var expected_count: int = OrbitalMechanics.predict_trajectory(
		sim.ship.global_position, sim.ship.linear_velocity,
		sim.planet_manager.planet_center_offset, sim.planet_manager.planet_radius,
		sim.ship.surface_gravity, 0.5, 64, PackedVector3Array()
	)
	_assert_int(expected_count, 0, "Empty destination buffer is handled")

	_start_test("Tier 4.3: HUD trajectory shifts with a floating-origin rebase")
	var before_rebase: PackedVector3Array = sim.hud.trajectory_points.duplicate()
	var offset: Vector3 = Vector3(2_000.0, -300.0, 500.0)
	sim.floating_origin.rebase(offset)
	for i in range(sim.hud.trajectory_count):
		_assert_vec3(sim.hud.trajectory_points[i], before_rebase[i] - offset, 1e-4,
			"HUD trajectory point %d shifted by the rebase" % i)
	_assert_vec3(sim.hud.trajectory_points[0], before_rebase[0] - offset, 1e-4,
		"Rebase shifts the first trajectory point")

	_start_test("Tier 4.4: 1,000 simulation ticks with zero static memory growth")
	sim.ship.global_position = Vector3.ZERO
	sim.ship.linear_velocity = Vector3(985.0, 0.0, 0.0)
	sim.floating_origin.rebase_threshold = 1.0e12
	for i in range(120):
		sim.step_simulation(DT)
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		sim.step_simulation(DT)
	var memory_after: int = OS.get_static_memory_usage()
	_assert(memory_after - memory_before <= 0,
		"step_simulation steady state has zero static memory growth (%d bytes)" % (
			memory_after - memory_before
		))
	_assert_int(sim.hud.trajectory_points.size(), 64, "HUD buffer remains fixed-size")
	_assert(sim.environment.current_atmosphere_factor > 0.9 and
		sim.environment.current_atmosphere_factor <= 1.0,
		"Environment tracks the atmospheric vessel")
	_dispose_sim(sim)

func _run_tier_5() -> void:
	print("\n--- Tier 5: Production Guardrails and Phase 1-4 Regression Gate ---")
	_start_test("Tier 5.1: All production scripts declare class_name and stay <= 250 lines")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert(production_files.size() >= 25, "Discovered all 25 production scripts")
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = text.split("\n").size()
		if text.ends_with("\n"):
			line_count -= 1
		_assert(line_count > 0 and line_count <= 250,
			"%s has %d lines (limit 250)" % [file, line_count])
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
	_assert(production_files.has("OrbitalMechanics.gd"), "OrbitalMechanics is a production script")
	_assert(production_files.has("PlanetaryEnvironment.gd"),
		"PlanetaryEnvironment is a production script")
	_assert(production_files.has("CockpitHUD.gd"), "CockpitHUD is a production script")
	_assert(production_files.has("FlightInputBindings.gd"),
		"FlightInputBindings is a production script")

	if OS.get_cmdline_user_args().has("--direct-regression"):
		print("  [SKIP] Nested Phase 1-4 regression gate (direct Phase 9 orchestration)")
		return
	_start_test("Tier 5.2: All 17 existing Phase 1-4 suites pass")
	var suites: Array[String] = [
		"test_adversarial_challenger2.gd",
		"test_adversarial_challenger_hardening.gd",
		"test_adversarial_edge_cases.gd",
		"test_adversarial_empirical.gd",
		"test_adversarial_hardening.gd",
		"test_adversarial_m10_reviewer2.gd",
		"test_adversarial_m12_challenger.gd",
		"test_adversarial_m12_challenger2.gd",
		"test_adversarial_m13_challenger1.gd",
		"test_adversarial_m13_challenger2.gd",
		"test_adversarial_m13_reviewer2.gd",
		"test_adversarial_m8_reviewer2.gd",
		"test_floating_origin_headless.gd",
		"test_phase2_terrain_gravity_headless.gd",
		"test_phase3_streaming_projectiles_headless.gd",
		"test_phase4_simulation_autopilot_headless.gd",
		"test_quadtree_headless.gd"
	]
	_assert_int(suites.size(), 17, "Discovered all 17 prior headless suites")
	var executable: String = OS.get_executable_path()
	for suite in suites:
		var output: Array = []
		var exit_code: int = OS.execute(
			executable,
			PackedStringArray([
				"--headless", "-s", ProjectSettings.globalize_path("res://" + suite)
			]),
			output,
			true
		)
		_assert_int(exit_code, 0, "%s exited successfully" % suite)
		if exit_code != 0:
			printerr("    [SUITE OUTPUT] %s" % str(output))
