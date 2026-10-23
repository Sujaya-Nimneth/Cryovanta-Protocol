extends SceneTree

## Phase 4 headless verification suite for the unified simulation and autopilot.
## Run with: godot --headless -s test_phase4_simulation_autopilot_headless.gd

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

var PlanetarySimulationClass = null
var FlightGuidanceSystemClass = null
var PlanetSurfaceMaterialClass = null
var SimulationTelemetryClass = null
var PlanetManagerClass = null
var PlanetStreamerClass = null
var ProjectilePoolManagerClass = null
var SpaceshipWeaponSystemClass = null
var SpaceshipControllerClass = null
var TerrainMeshBuilderClass = null

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 4 Headless Verification Suite (Tiers 1-5)")
	print("==================================================================")
	await process_frame
	_load_classes()
	await _run_tier_1()
	await _run_tier_2()
	_run_tier_3()
	await _run_tier_4()
	_run_tier_5()
	_print_summary()
	quit(0 if failed_assertions == 0 else 1)

func _load_classes() -> void:
	PlanetarySimulationClass = load("res://PlanetarySimulation.gd")
	FlightGuidanceSystemClass = load("res://FlightGuidanceSystem.gd")
	PlanetSurfaceMaterialClass = load("res://PlanetSurfaceMaterial.gd")
	SimulationTelemetryClass = load("res://SimulationTelemetry.gd")
	PlanetManagerClass = load("res://PlanetManager.gd")
	PlanetStreamerClass = load("res://PlanetStreamer.gd")
	ProjectilePoolManagerClass = load("res://ProjectilePoolManager.gd")
	SpaceshipWeaponSystemClass = load("res://SpaceshipWeaponSystem.gd")
	SpaceshipControllerClass = load("res://SpaceshipController.gd")
	TerrainMeshBuilderClass = load("res://TerrainMeshBuilder.gd")
	_start_test("Load Phase 4 classes and main scene")
	_assert(PlanetarySimulationClass != null, "PlanetarySimulation.gd failed to load")
	_assert(FlightGuidanceSystemClass != null, "FlightGuidanceSystem.gd failed to load")
	_assert(PlanetSurfaceMaterialClass != null, "PlanetSurfaceMaterial.gd failed to load")
	_assert(SimulationTelemetryClass != null, "SimulationTelemetry.gd failed to load")
	_assert(ResourceLoader.exists("res://main.tscn"), "main.tscn exists")
	_assert(ProjectSettings.get_setting("application/run/main_scene", "") == "res://main.tscn", "Main scene is registered")

func _start_test(test_name: String) -> void:
	current_test_name = test_name
	print("  [TEST] %s" % test_name)

func _pass() -> void:
	passed_assertions += 1
	total_assertions += 1

func _fail(reason: String) -> void:
	failed_assertions += 1
	total_assertions += 1
	printerr("    [FAIL] %s: %s" % [current_test_name, reason])

func _assert(condition: bool, message: String) -> void:
	if condition:
		_pass()
	else:
		_fail(message)

func _assert_int(actual: int, expected: int, message: String) -> void:
	_assert(actual == expected, "%s (expected %d, got %d)" % [message, expected, actual])

func _assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assert(absf(actual - expected) <= tolerance, "%s (expected %.8f, got %.8f)" % [message, expected, actual])

func _assert_vec3(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> void:
	_assert(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func _print_summary() -> void:
	print("\n==================================================================")
	print("PHASE 4 TEST SUITE EXECUTION SUMMARY")
	print("==================================================================")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	print("==================================================================")
	if failed_assertions == 0:
		print("SUCCESS: All %d assertions passed with exit code 0!" % total_assertions)
	else:
		printerr("FAILURE: %d out of %d assertions failed!" % [failed_assertions, total_assertions])

func _instantiate_main() -> Node:
	var packed: PackedScene = load("res://main.tscn")
	var sim: Node = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	return sim

func _prepare_stream(sim: Node) -> void:
	sim.planet_manager.max_lod = 4
	var camera_position: Vector3 = sim.camera.global_position
	for i in range(6):
		sim.planet_manager.update_camera(camera_position)
	sim.planet_streamer.update_streamer(camera_position)

func _settle_terrain_physics(sim: Node) -> void:
	for leaf in sim.planet_manager.get_all_leaves():
		if leaf.collider_id != -1:
			sim.planet_manager.collider_pool.get_body(leaf.collider_id).force_update_transform()
	await physics_frame
	await physics_frame

func _dispose_sim(sim: Node) -> void:
	if sim == null:
		return
	sim.destroy()
	if sim.get_parent() == get_root():
		get_root().remove_child(sim)
	sim.free()

func _run_tier_1() -> void:
	print("\n--- Tier 1: Unified Planetary Simulation and Rebase Synchronization ---")
	_start_test("Tier 1.1: main.tscn hierarchy and physical ship wiring")
	var sim: Node = _instantiate_main()
	await process_frame
	_assert(sim.is_setup, "PlanetarySimulation setup completed")
	_assert(sim.planet_manager != null and sim.planet_manager.get_parent() == sim, "PlanetManager is wired")
	_assert(sim.planet_streamer != null and sim.planet_streamer.planet_manager == sim.planet_manager, "PlanetStreamer is wired")
	_assert(sim.floating_origin.player_node == sim.ship, "FloatingOrigin tracks the ship")
	_assert(sim.ship.planet_manager == sim.planet_manager, "Ship uses the shared planet manager")
	_assert(sim.ship.enable_planetary_gravity, "Planetary gravity is enabled")
	_assert_int(sim.ship.collision_layer, 2, "Ship collision layer")
	_assert_int(sim.ship.collision_mask, 1, "Ship collision mask")
	_assert_vec3(sim.ship.global_position, Vector3.ZERO, 0.01, "Ship starts at the world origin")
	var startup_center := Vector3(0.0, -(sim.planet_manager.planet_radius + sim.initial_altitude), 0.0)
	_assert_vec3(sim.planet_manager.planet_center_offset, startup_center, 1e-4, "Planet center starts below the vessel")
	_assert_approx(sim.ship.get_current_altitude(), sim.initial_altitude, 0.01, "Ship starts at the configured altitude")
	var collision_shape: CollisionShape3D = sim.ship.get_node("ShipCollision")
	_assert(collision_shape.shape is SphereShape3D, "Ship has a sphere collider")
	if collision_shape.shape is SphereShape3D:
		_assert_approx(collision_shape.shape.radius, 2.0, 1e-9, "Ship collider radius")
	_assert(sim.camera.get_parent() == sim.ship, "Camera is protected under the ship hierarchy")
	_assert_vec3(sim.camera.position, Vector3(0.0, 3.0, 8.0), 1e-9, "Camera local offset")
	_assert(sim.weapon_system.ship == sim.ship, "Weapon system links the ship")
	_assert(sim.weapon_system.projectile_pool == sim.projectile_pool, "Weapon system links the projectile pool")
	_assert(sim.guidance.ship == sim.ship, "Guidance links the ship")
	_assert(sim.guidance.weapon_system == sim.weapon_system, "Guidance links the radar")

	_start_test("Tier 1.2: One-frame visual, collider, projectile, and shader rebase")
	_prepare_stream(sim)
	var leaves: Array = sim.planet_manager.get_all_leaves()
	var high_leaf = null
	for leaf in leaves:
		if leaf.collider_id != -1:
			high_leaf = leaf
			break
	_assert(high_leaf != null, "Streaming produced a baked terrain collider")
	if high_leaf == null:
		_dispose_sim(sim)
		return
	var visual: MeshInstance3D = sim.planet_streamer.visuals[high_leaf.mesh_id]
	var body: StaticBody3D = sim.planet_manager.collider_pool.get_body(high_leaf.collider_id)
	_assert_vec3(visual.global_position, body.global_position, 1e-4, "Visual and collider origins align before rebase")
	var projectile_id: int = sim.projectile_pool.spawn_projectile(
		body.global_position + Vector3.UP * 10.0, Vector3(12.0, -3.0, 7.0), 100.0
	)
	_assert(projectile_id >= 0, "Simulation projectile spawned")
	sim.ship.global_position = body.global_position + Vector3.UP * 100.0
	sim.ship.linear_velocity = Vector3(45.0, -8.0, 3.0)
	sim.ship.angular_velocity = Vector3(0.1, -0.2, 0.05)
	var ship_pos: Vector3 = sim.ship.global_position
	var ship_vel: Vector3 = sim.ship.linear_velocity
	var ship_spin: Vector3 = sim.ship.angular_velocity
	var projectile_pos: Vector3 = sim.projectile_pool.positions[projectile_id]
	var projectile_vel: Vector3 = sim.projectile_pool.velocities[projectile_id]
	var visual_pos: Vector3 = visual.global_position
	var body_pos: Vector3 = body.global_position
	var offset: Vector3 = Vector3(2_000.0, 0.0, -500.0)
	sim.floating_origin.rebase(offset)
	_assert_vec3(sim.ship.global_position, ship_pos - offset, 1e-4, "Ship shifted by the origin rebase")
	_assert_vec3(sim.ship.linear_velocity, ship_vel, 1e-5, "Ship linear velocity is continuous")
	_assert_vec3(sim.ship.angular_velocity, ship_spin, 1e-5, "Ship angular velocity is continuous")
	_assert_vec3(sim.planet_manager.planet_center_offset, startup_center - offset, 1e-4, "Planet center offset shifted")
	_assert_vec3(sim.planet_streamer.global_position, sim.planet_manager.planet_center_offset, 1e-4, "Streamer root follows planet center")
	_assert_vec3(visual.global_position, visual_pos - offset, 1e-4, "Visual chunk shifted with the planet")
	_assert_vec3(body.global_position, body_pos - offset, 1e-4, "Collider body shifted with the planet")
	_assert_vec3(visual.global_position, body.global_position, 1e-4, "Visual and collider remain aligned after rebase")
	_assert_vec3(sim.projectile_pool.positions[projectile_id], projectile_pos - offset, 1e-4, "Projectile shifted by the rebase")
	_assert_vec3(sim.projectile_pool.velocities[projectile_id], projectile_vel, 1e-5, "Projectile velocity is continuous")
	_assert_vec3(sim.surface_material.planet_center_offset, sim.planet_manager.planet_center_offset, 1e-4, "Shader center uniform follows rebase")
	_assert_vec3(sim.camera.global_position, sim.ship.global_position + sim.camera.position, 1e-4, "Camera follows the rebased ship")
	_assert(sim.planet_manager.audit_system()["is_valid"], "Simulation preserved quadtree and collider integrity")

	_start_test("Tier 1.3: Radar and projectile exclude the layer-2 ship collider")
	sim.ship.global_position = Vector3(100.0, 0.0, 100.0)
	_prepare_stream(sim)
	await _settle_terrain_physics(sim)
	var space_state: PhysicsDirectSpaceState3D = get_root().get_world_3d().direct_space_state
	var oracle: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	var excluded: Array[RID] = [sim.ship.get_rid()]
	oracle.from = sim.ship.global_position
	var oracle_radial: Vector3 = (
		sim.ship.global_position - sim.planet_manager.planet_center_offset
	).normalized()
	oracle.to = sim.ship.global_position - oracle_radial * 5_000.0
	oracle.collision_mask = 1
	oracle.exclude = excluded
	oracle.collide_with_bodies = true
	oracle.collide_with_areas = false
	oracle.hit_from_inside = true
	oracle.hit_back_faces = true
	var oracle_hit: Dictionary = space_state.intersect_ray(oracle)
	_assert(not oracle_hit.is_empty(), "Physics oracle found terrain below the ship")
	var measured_altitude: float = sim.weapon_system.measure_radar_altitude(space_state, 5_000.0)
	_assert(measured_altitude > 0.0 and measured_altitude < 5_000.0, "Radar measured live terrain below the ship")
	if not oracle_hit.is_empty():
		var oracle_distance: float = sim.ship.global_position.distance_to(oracle_hit["position"])
		_assert_approx(measured_altitude, oracle_distance, 1e-3, "Radar matches the live terrain oracle")
		_assert(oracle_hit["collider"] != sim.ship, "Oracle terrain hit is not the ship")
	_assert(sim.weapon_system.get_radar_query().exclude[0] == sim.ship.get_rid(), "Radar query excludes the ship RID")
	sim.weapon_system.terrain_collision_mask = 3
	var overlap_altitude: float = sim.weapon_system.measure_radar_altitude(space_state, 5_000.0)
	_assert(overlap_altitude > 0.0 and overlap_altitude < 5_000.0, "Radar exclusion prevents a ship self-hit on overlapping layers")
	sim.weapon_system.terrain_collision_mask = 1
	sim.ship.linear_velocity = -sim.ship.global_transform.basis.z * 100.0
	sim.projectile_pool.clear()
	var fired_projectile_id: int = sim.weapon_system.fire_projectile()
	_assert(fired_projectile_id >= 0, "Weapon fired from the live simulation ship")
	var impacts: int = sim.projectile_pool.step_projectiles(1.0 / 120.0, space_state)
	_assert_int(impacts, 0, "Projectile did not self-impact the ship on launch")
	_assert_int(sim.projectile_pool.active_count, 1, "Projectile remains active after launch")
	if fired_projectile_id >= 0:
		sim.projectile_pool.release_projectile(fired_projectile_id)
	sim.ship.linear_velocity = Vector3.ZERO
	_dispose_sim(sim)

func _make_guidance_fixture() -> Array:
	var planet: PlanetManager = PlanetManagerClass.new()
	planet.max_lod = 1
	get_root().add_child(planet)
	var ship: SpaceshipController = SpaceshipControllerClass.new()
	ship.planet_manager = planet
	ship.enable_planetary_gravity = true
	ship.process_user_input = false
	ship.set_physics_process(false)
	ship.mass = 1_000.0
	ship.freeze = true
	get_root().add_child(ship)
	var weapon: SpaceshipWeaponSystem = SpaceshipWeaponSystemClass.new()
	weapon.ship = ship
	weapon.planet_manager = planet
	get_root().add_child(weapon)
	var guidance: FlightGuidanceSystem = FlightGuidanceSystemClass.new()
	guidance.ship = ship
	guidance.weapon_system = weapon
	guidance.planet_manager = planet
	get_root().add_child(guidance)
	return [planet, ship, weapon, guidance]

func _dispose_guidance_fixture(fixture: Array) -> void:
	var ship: SpaceshipController = fixture[1]
	ship.linear_velocity = Vector3.ZERO
	ship.angular_velocity = Vector3.ZERO
	for node in [fixture[3], fixture[2], ship, fixture[0]]:
		if node.get_parent() == get_root():
			get_root().remove_child(node)
		if node == fixture[0]:
			node.destroy()
		node.free()

func _integrate_attitude(ship: SpaceshipController, guidance: FlightGuidanceSystem, steps: int, dt: float) -> void:
	var inertia: Vector3 = Vector3(2_000.0, 2_000.0, 3_000.0)
	for i in range(steps):
		guidance.update_guidance(dt)
		var authority: Vector3 = Vector3(ship.pitch_torque, ship.yaw_torque, ship.roll_torque)
		var accel_local: Vector3 = ship.torque_input * authority / inertia
		var accel_world: Vector3 = ship.global_transform.basis * accel_local
		ship.angular_velocity += accel_world * dt
		var omega: Vector3 = ship.angular_velocity
		if omega.length_squared() > 1e-12:
			var q: Quaternion = ship.global_transform.basis.get_rotation_quaternion()
			var dq: Quaternion = Quaternion(omega.normalized(), omega.length() * dt)
			ship.global_transform.basis = Basis((dq * q).normalized())

func _step_vertical_flight(ship: SpaceshipController, guidance: FlightGuidanceSystem, steps: int, dt: float) -> void:
	var radial_up: Vector3 = (ship.global_position - ship.get_planet_center()).normalized()
	for i in range(steps):
		ship._apply_flight_forces()
		guidance.update_guidance(dt)
		var longitudinal_thrust: float = ship.forward_thrust if ship.thrust_input.z >= 0.0 else ship.reverse_thrust
		var thrust_local: Vector3 = Vector3(
			ship.thrust_input.x * ship.strafe_thrust,
			ship.thrust_input.y * ship.vertical_thrust,
			-ship.thrust_input.z * longitudinal_thrust
		)
		var accel: Vector3 = ship.get_current_gravity() / ship.mass
		accel += (ship.global_transform.basis * thrust_local) / ship.mass
		accel += ship.get_current_drag() / ship.mass
		ship.linear_velocity += accel * dt
		ship.global_position += ship.linear_velocity * dt

func _run_tier_2() -> void:
	print("\n--- Tier 2: 6-DOF SAS, Radial-Up, Hover, and Soft Landing ---")
	var fixture: Array = _make_guidance_fixture()
	var planet: PlanetManager = fixture[0]
	var ship: SpaceshipController = fixture[1]
	var guidance: FlightGuidanceSystem = fixture[3]
	ship.global_position = Vector3(0.0, planet.planet_radius + 500.0, 0.0)
	ship.global_transform.basis = Basis.IDENTITY
	ship.angular_velocity = Vector3(1.2, -0.8, 0.6)
	var spin_initial: float = ship.angular_velocity.length()
	guidance.mode = FlightGuidanceSystem.MODE_SAS_HOLD
	_integrate_attitude(ship, guidance, 720, 1.0 / 120.0)
	var spin_final: float = ship.angular_velocity.length()
	_assert(spin_final <= spin_initial * 0.05, "SAS reduced angular speed by more than 95%% (%.6f -> %.6f)" % [spin_initial, spin_final])

	_start_test("Tier 2.2: Radial-up attitude alignment")
	ship.global_transform.basis = Basis(Vector3.UP, 0.65) * Basis(Vector3.RIGHT, 0.42)
	ship.angular_velocity = Vector3(0.35, -0.2, 0.15)
	guidance.mode = FlightGuidanceSystem.MODE_RADIAL_UP
	_integrate_attitude(ship, guidance, 720, 1.0 / 120.0)
	var up_alignment: float = ship.global_transform.basis.y.normalized().dot(Vector3.UP)
	_assert(up_alignment > 0.95, "Radial-up alignment exceeded 0.95 (got %.6f)" % up_alignment)
	_assert(ship.angular_velocity.length() < 0.1, "Radial-up guidance damped residual spin")

	_start_test("Tier 2.3: Hover altitude hold under planetary gravity")
	ship.global_transform.basis = Basis.IDENTITY
	ship.global_position = Vector3(0.0, planet.planet_radius + 500.0, 0.0)
	ship.linear_velocity = Vector3(0.0, -10.0, 0.0)
	guidance.mode = FlightGuidanceSystem.MODE_HOVER
	guidance.target_altitude = 500.0
	_step_vertical_flight(ship, guidance, 900, 1.0 / 120.0)
	var hover_altitude: float = ship.get_current_altitude()
	_assert(absf(hover_altitude - 500.0) < 15.0, "Hover held target altitude within 15 m (got %.3f)" % hover_altitude)
	_assert(absf(ship.linear_velocity.dot(Vector3.UP)) < 2.0, "Hover bounded radial speed")

	_start_test("Tier 2.4: Soft landing under gravity and origin rebase")
	ship.global_transform.basis = Basis.IDENTITY
	ship.global_position = Vector3(0.0, planet.planet_radius + 300.0, 0.0)
	ship.linear_velocity = Vector3(5.0, -20.0, -2.0)
	guidance.mode = FlightGuidanceSystem.MODE_SOFT_LAND
	var profile_ok: bool = true
	var touchdown_speed: float = 0.0
	var touchdown_horizontal: float = 0.0
	var monotonic_descent: bool = true
	var previous_altitude: float = ship.get_current_altitude()
	for i in range(1_800):
		_step_vertical_flight(ship, guidance, 1, 1.0 / 120.0)
		if guidance._target_radial_speed > -guidance.min_descent_speed - 1e-6:
			profile_ok = profile_ok and guidance._target_radial_speed >= -guidance.max_descent_speed
		if i == 600:
			var velocity_before: Vector3 = ship.linear_velocity
			var rebase: Vector3 = Vector3(2_000.0, 0.0, -500.0)
			ship.rebase_origin(rebase)
			planet.rebase_origin(rebase)
			_assert_vec3(ship.linear_velocity, velocity_before, 1e-5, "Soft-land velocity is continuous across rebase")
		var altitude: float = ship.get_current_altitude()
		if altitude > previous_altitude + 1e-6 or ship.linear_velocity.dot(Vector3.UP) > 1e-6:
			monotonic_descent = false
		previous_altitude = altitude
		if altitude <= guidance.touchdown_margin:
			touchdown_speed = -ship.linear_velocity.dot(Vector3.UP)
			var horizontal: Vector3 = ship.linear_velocity - Vector3.UP * ship.linear_velocity.dot(Vector3.UP)
			touchdown_horizontal = horizontal.length()
			break
	_assert(profile_ok, "Soft-land descent profile stayed within speed bounds")
	_assert(monotonic_descent, "Soft landing descended monotonically without bouncing")
	_assert(touchdown_speed >= -0.01 and touchdown_speed <= 1.5, "Soft landing touchdown vertical speed is safe (got %.4f)" % touchdown_speed)
	_assert(touchdown_horizontal < 0.5, "Soft landing zeroed horizontal slip (got %.4f)" % touchdown_horizontal)

	_start_test("Tier 2.5: Low-altitude soft landing without upward thrust bounce")
	ship.global_transform.basis = Basis.IDENTITY
	ship.global_position = planet.planet_center_offset + Vector3(0.0, planet.planet_radius + 8.0, 0.0)
	ship.linear_velocity = Vector3(0.0, -1.5, 0.0)
	guidance.mode = FlightGuidanceSystem.MODE_SOFT_LAND
	previous_altitude = 8.0
	monotonic_descent = true
	var low_landing_reached: bool = false
	for i in range(600):
		_step_vertical_flight(ship, guidance, 1, 1.0 / 120.0)
		var altitude: float = ship.get_current_altitude()
		if altitude > previous_altitude + 1e-6 or ship.linear_velocity.dot(Vector3.UP) > 1e-6:
			monotonic_descent = false
		previous_altitude = altitude
		if altitude <= guidance.touchdown_margin + 0.05:
			low_landing_reached = true
			break
	_assert(low_landing_reached, "Low-altitude landing reached the touchdown margin")
	_assert(monotonic_descent, "Low-altitude landing never bounced upward")
	_dispose_guidance_fixture(fixture)

func _run_tier_3() -> void:
	print("\n--- Tier 3: Shared Cryo-Terrain Material ---")
	_start_test("Tier 3.1: Shared material across 256 streamed visuals")
	var sim: Node = _instantiate_main()
	var shared: ShaderMaterial = sim.surface_material.material
	_assert(shared != null and shared.shader != null, "Surface shader and material exist")
	for i in range(256):
		_assert(sim.planet_streamer.visuals[i].material_override == shared, "Visual %d shares the terrain material" % i)
	var uniforms: Array[String] = [
		"planet_center_offset", "planet_radius", "max_elevation",
		"lowland_color", "slope_color", "highland_ice_color"
	]
	for uniform in uniforms:
		_assert(shared.get_shader_parameter(uniform) != null, "Shader exposes %s" % uniform)
	_start_test("Tier 3.2: Shader uniform synchronization on origin rebase")
	var offset: Vector3 = Vector3(2_000.0, 500.0, -1_000.0)
	sim.floating_origin.rebase(offset)
	var uniform_center: Vector3 = shared.get_shader_parameter("planet_center_offset")
	_assert_vec3(uniform_center, sim.planet_manager.planet_center_offset, 1e-4, "planet_center_offset uniform synchronized")
	_assert_approx(shared.get_shader_parameter("planet_radius"), sim.planet_manager.planet_radius, 1e-6, "planet_radius uniform synchronized")
	_dispose_sim(sim)

func _run_tier_4() -> void:
	print("\n--- Tier 4: Telemetry Accuracy and Zero-Growth Steady State ---")
	_start_test("Tier 4.1: Flight, pool, and sector telemetry")
	var sim: Node = _instantiate_main()
	sim.planet_manager.max_lod = 1
	sim.ship.global_position = Vector3.ZERO
	sim.ship.linear_velocity = Vector3(40.0, 30.0, 12.0)
	sim.ship.angular_velocity = Vector3.ZERO
	sim.projectile_pool.spawn_projectile(sim.ship.global_position, Vector3.RIGHT * 100.0, 100.0)
	sim.projectile_pool.spawn_projectile(sim.ship.global_position, Vector3.LEFT * 100.0, 100.0)
	sim.floating_origin.origin_sector = Vector3i(2, -3, 4)
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.step_simulation(1.0 / 120.0)
	var telemetry = sim.telemetry
	_assert_approx(telemetry.vertical_speed, 30.0, 0.05, "Vertical speed decomposes along radial up")
	_assert_approx(telemetry.horizontal_speed, sqrt(40.0 * 40.0 + 12.0 * 12.0), 0.05, "Horizontal speed is tangential")
	_assert_approx(telemetry.total_speed, sim.ship.linear_velocity.length(), 1e-5, "Total speed matches ship velocity")
	_assert_approx(telemetry.gravity_magnitude, sim.ship.get_current_gravity().length() / sim.ship.mass, 1e-5, "Gravity telemetry matches ship")
	_assert_approx(telemetry.drag_magnitude, sim.ship.get_current_drag().length(), 1e-5, "Drag telemetry matches ship")
	_assert_approx(telemetry.air_density, sim.ship.get_current_density(), 1e-6, "Air density telemetry matches ship")
	var expected_g: float = sim.ship.get_current_net_force().length() / (sim.ship.mass * 9.80665)
	_assert_approx(telemetry.g_load, expected_g, 1e-5, "G-load reflects net force")
	_assert_int(telemetry.active_leaves, sim.planet_manager.chunk_pool.active_count, "Active leaf telemetry")
	_assert_int(telemetry.active_visuals, sim.planet_streamer.get_active_visual_count(), "Active visual telemetry")
	_assert_int(telemetry.active_colliders, sim.planet_manager.collider_pool.active_count, "Active collider telemetry")
	_assert_int(telemetry.active_projectiles, 2, "Active projectile telemetry")
	_assert(telemetry.origin_sector == Vector3i(2, -3, 4), "Origin sector telemetry")

	_start_test("Tier 4.2: 1,000 ticks without static memory growth")
	sim.projectile_pool.clear()
	sim.ship.global_position = Vector3.ZERO
	sim.ship.linear_velocity = Vector3.ZERO
	for i in range(120):
		sim.step_simulation(1.0 / 120.0)
	var before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		sim.step_simulation(1.0 / 120.0)
	var after: int = OS.get_static_memory_usage()
	_assert(after - before <= 0, "step_simulation steady state has zero static memory growth (%d bytes)" % (after - before))
	_dispose_sim(sim)

func _run_tier_5() -> void:
	print("\n--- Tier 5: Guardrails and Phase 1-3 Regression Gate ---")
	_start_test("Tier 5.1: All production class names and line limits")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert(production_files.size() >= 18, "Discovered all production scripts")
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = text.split("\n").size()
		if text.ends_with("\n"):
			line_count -= 1
		_assert(line_count <= 250, "%s has %d lines (limit 250)" % [file, line_count])
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
		if file == "PlanetStreamer.gd":
			_assert(line_count <= 240, "PlanetStreamer.gd has %d lines (limit 240)" % line_count)

	if OS.get_cmdline_user_args().has("--direct-regression"):
		print("  [SKIP] Nested Phase 1-3 regression gate (direct Phase 9 orchestration)")
		return
	_start_test("Tier 5.2: All 16 prior headless suites pass")
	var suites: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.begins_with("test_") and file.ends_with(".gd") \
			and file != "test_phase4_simulation_autopilot_headless.gd" \
			and file != "test_phase5_orbital_hud_environment_headless.gd" \
			and file != "test_phase6_targets_combat_mobile_headless.gd" \
			and file != "test_phase7_thermal_governor_encounters_headless.gd" \
			and file != "test_phase8_waypoints_evasion_hud_headless.gd":
			suites.append(file)
	suites.sort()
	_assert_int(suites.size(), 16, "Discovered all 16 prior headless suites")
	var executable: String = OS.get_executable_path()
	for suite in suites:
		var output: Array = []
		var exit_code: int = OS.execute(
			executable,
			PackedStringArray(["--headless", "-s", ProjectSettings.globalize_path("res://" + suite)]),
			output,
			true
		)
		_assert_int(exit_code, 0, "%s exited successfully" % suite)
		if exit_code != 0:
			printerr("    [SUITE OUTPUT] %s" % str(output))
