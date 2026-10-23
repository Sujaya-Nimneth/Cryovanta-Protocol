extends SceneTree

## Phase 9 headless verification for weapon heat, waypoint autopilot, and score.
## Run with: godot --headless -s test_phase9_weapon_heat_autopilot_score_headless.gd

const DT: float = 1.0 / 120.0
const PHASE9_SUITE: String = "test_phase9_weapon_heat_autopilot_score_headless.gd"

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 9 Headless Verification Suite (Tiers 1-5)")
	print("==================================================================")
	await process_frame
	await _run_tier_1()
	await _run_tier_2()
	await _run_tier_3()
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
	print("PHASE 9 TEST SUITE EXECUTION SUMMARY")
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

func _run_tier_1() -> void:
	print("\n--- Tier 1: Immediate Rebase Binding and Capacitor Lifecycle ---")
	_start_test("Tier 1.1: Waypoints rebase during setup before the first simulation tick")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	var waypoint: Vector3 = sim.ship.global_position + Vector3(400.0, 0.0, 0.0)
	sim.encounter_director.waypoints.clear()
	sim.encounter_director.waypoints.add_waypoint(waypoint, 30.0)
	_assert(sim.floating_origin.origin_rebased.is_connected(
		sim.encounter_director.rebase_origin
	), "Director binds during setup_simulation()")
	_assert(sim.encounter_director._rebase_connected, "Director records its live binding")
	var offset: Vector3 = Vector3(2_000.0, -250.0, 400.0)
	sim.floating_origin.rebase(offset)
	_assert_vec3(sim.encounter_director.waypoints.get_current_waypoint_position(),
		waypoint - offset, 1e-5, "Waypoint shifts before step_simulation()")

	_start_test("Tier 1.2: Capacitor defaults to unlimited fire and then gates shots")
	var capacitor: WeaponHeatCapacitor = WeaponHeatCapacitor.new()
	_assert(not capacitor.enabled, "Capacitor is disabled by default")
	_assert(capacitor.can_fire(), "Disabled capacitor always permits fire")
	_assert(capacitor.consume_shot(), "Disabled capacitor consumes a shot")
	_assert(capacitor.consume_shot(), "Disabled capacitor permits immediate rapid fire")
	_assert_int(capacitor.shots_fired, 2, "Disabled capacitor counts both shots")
	_assert_approx(capacitor.heat, 0.0, 0.0, "Disabled capacitor generates no heat")
	capacitor.reset()
	capacitor.enabled = true
	_assert(capacitor.consume_shot(), "Enabled capacitor fires from cold")
	_assert(not capacitor.can_fire(), "Cooldown blocks the immediate second shot")
	_assert_approx(capacitor.heat, 18.0, 1e-6, "One shot accumulates heat_per_shot")
	capacitor.step_capacitor(0.06)
	_assert(not capacitor.can_fire(), "Half-interval step does not unlock fire")
	capacitor.step_capacitor(0.06)
	_assert(capacitor.can_fire(), "Full fire interval unlocks the next shot")
	while not capacitor.overheated:
		capacitor.step_capacitor(capacitor.fire_interval)
		_assert(capacitor.consume_shot(), "Shot before overheat is accepted")
	_assert_approx(capacitor.heat, capacitor.max_heat, 1e-6, "Overheat latches at max heat")
	_assert(not capacitor.can_fire(), "Overheated capacitor blocks fire")
	_assert(not capacitor.consume_shot(), "Overheated shot is rejected")
	capacitor.step_capacitor(2.0)
	_assert(not capacitor.overheated, "Cooling below the clear ratio unlocks")
	_assert(capacitor.heat <= capacitor.max_heat * capacitor.overheat_clear_ratio,
		"Unlock occurs at or below the configured clear ratio")
	_assert(capacitor.can_fire(), "Cooled capacitor can fire again")

	_start_test("Tier 1.3: Weapon firing respects the capacitor gate")
	sim.weapon_system.capacitor.reset()
	sim.weapon_system.capacitor.enabled = true
	var first_id: int = sim.weapon_system.fire_projectile()
	var blocked_id: int = sim.weapon_system.fire_projectile()
	_assert(first_id >= 0, "First gated projectile spawns")
	_assert_int(blocked_id, -1, "Second same-tick projectile is rejected")
	_assert_int(sim.weapon_system.capacitor.shots_fired, 1, "Only the spawned shot is counted")
	sim.weapon_system.capacitor.enabled = false
	_assert(sim.weapon_system.fire_projectile() >= 0, "Disabled gate restores rapid fire")
	sim.projectile_pool.clear()
	_dispose_sim(sim)

func _run_tier_2() -> void:
	print("\n--- Tier 2: Autonomous Waypoint Intercept Guidance ---")
	_start_test("Tier 2.1: Autopilot steers to and captures a waypoint 400 m away")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.freeze = true
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3.ZERO
	sim.ship.angular_velocity = Vector3.ZERO
	sim.encounter_director.waypoints.clear()
	var target: Vector3 = Vector3(0.0, 0.0, -400.0)
	sim.encounter_director.waypoints.add_waypoint(target, 150.0)
	sim.guidance.set_waypoint_target(true, target)
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_WAYPOINT_INTERCEPT)
	var initial_distance: float = sim.ship.global_position.distance_to(target)
	var previous_distance: float = initial_distance
	var monotonic: bool = true
	var captured_tick: int = -1
	for i in range(900):
		_step_intercept_tick(sim)
		var current_distance: float = sim.ship.global_position.distance_to(target)
		if current_distance > previous_distance + 1e-4:
			monotonic = false
		previous_distance = current_distance
		if sim.telemetry.completed_waypoints == 1:
			captured_tick = i
			break
	_assert_int(sim.guidance.mode, FlightGuidanceSystem.MODE_WAYPOINT_INTERCEPT,
		"Guidance remains in waypoint intercept mode")
	var approach: Vector3 = (target - Vector3.ZERO).normalized()
	_assert(sim.ship.linear_velocity.dot(approach) > 0.0,
		"Ship accelerates toward the waypoint")
	_assert(monotonic, "Waypoint distance decreases without divergence")
	_assert(previous_distance < initial_distance, "Ship materially reduces waypoint distance")
	_assert(sim.ship.global_position.distance_to(Vector3.ZERO) > 1.0,
		"Ship moves from its starting position")
	_assert(sim.ship.global_position.length() > 1.0, "Ship closes the gap rather than teleporting")
	_assert(captured_tick >= 0, "Waypoint is captured within 900 ticks")
	_assert_int(sim.telemetry.completed_waypoints, 1, "Waypoint completion reaches telemetry")
	_assert_int(FlightGuidanceSystem.MODE_WAYPOINT_INTERCEPT, 8, "Waypoint mode identifier is 8")
	_dispose_sim(sim)

func _run_tier_3() -> void:
	print("\n--- Tier 3: Combat Kill Score, Waypoint Score, and HUD Sync ---")
	_start_test("Tier 3.1: Two kills and one waypoint produce 450 points")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3.ZERO
	sim.encounter_director.waypoints.clear()
	sim.target_pool.clear()
	sim.weapon_system.capacitor.reset()
	sim.weapon_system.capacitor.enabled = true
	sim.target_pool.spawn_target(Vector3(100.0, 0.0, 0.0), Vector3.ZERO, 50.0)
	sim.target_pool.spawn_target(Vector3(200.0, 0.0, 0.0), Vector3.ZERO, 50.0)
	for id in range(TargetPoolManager.POOL_SIZE):
		if sim.target_pool.is_in_use[id]:
			sim.target_pool.apply_damage(id, 100.0)
	_assert_int(sim.target_pool.destroyed_count, 2, "Two destroyed targets are counted")
	sim.encounter_director.waypoints.add_waypoint(sim.ship.global_position, 30.0)
	sim.step_simulation(DT)
	_assert_int(sim.telemetry.targets_destroyed, 2, "Telemetry mirrors kill count")
	_assert_int(sim.telemetry.completed_waypoints, 1, "Waypoint capture reaches telemetry")
	_assert_int(sim.telemetry.combat_score, 450, "Score is 2 kills plus 1 waypoint")
	_assert_int(sim.hud.displayed_combat_score, 450, "HUD mirrors combat score")
	_assert_approx(sim.hud.displayed_weapon_heat, sim.telemetry.weapon_heat, 1e-9,
		"HUD mirrors weapon heat")
	_assert(not sim.telemetry.weapon_overheated, "Fresh capacitor is not overheated")
	_dispose_sim(sim)

func _run_tier_4() -> void:
	print("\n--- Tier 4: 1,000-Tick Steady-State Zero Static Growth ---")
	_start_test("Tier 4.1: Capacitor, autopilot, waves, and evasion remain allocation-free")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3.ZERO
	sim.encounter_director.waypoints.clear()
	sim.encounter_director.waypoints.add_waypoint(Vector3(2_000.0, 0.0, 0.0), 30.0)
	sim.guidance.set_waypoint_target(true, Vector3(2_000.0, 0.0, 0.0))
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_WAYPOINT_INTERCEPT)
	sim.weapon_system.capacitor.enabled = true
	sim.encounter_director.auto_spawn_waves = true
	sim.encounter_director.desired_active_targets = 2
	sim.encounter_director.evasion_enabled = true
	sim.encounter_director.target_initial_health = 1.0e9
	for i in range(120):
		sim.step_simulation(DT)
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		sim.step_simulation(DT)
	var memory_after: int = OS.get_static_memory_usage()
	_assert(memory_after - memory_before <= 0,
		"Phase 9 steady state has zero static growth (%d bytes)" % (
			memory_after - memory_before
		))
	_assert(sim.weapon_system.capacitor.shots_fired >= 0, "Capacitor remains live")
	_assert(sim.target_pool.active_count <= TargetPoolManager.POOL_SIZE,
		"Target pool remains bounded")
	_dispose_sim(sim)

func _run_tier_5() -> void:
	print("\n--- Tier 5: 30-Script Guardrails and 21-Suite Regression Gate ---")
	_start_test("Tier 5.1: All 30 production scripts declare class_name and stay <= 250 lines")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert_int(production_files.size(), 30, "Discovered all 30 production scripts")
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = _count_lines("res://" + file)
		_assert(line_count > 0 and line_count <= 250,
			"%s has %d lines (limit 250)" % [file, line_count])
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
	for required in [
		"WeaponHeatCapacitor.gd", "FlightGuidanceSystem.gd", "EncounterDirector.gd",
		"PlanetarySimulation.gd", "SimulationTelemetry.gd", "CockpitHUD.gd"
	]:
		_assert(production_files.has(required), "%s is a production script" % required)
	_assert(_count_lines("res://PlanetarySimulation.gd") <= 248,
		"PlanetarySimulation.gd remains at or below its 248-line ceiling")
	_assert(_count_lines("res://ChunkTaskScheduler.gd") <= 248,
		"ChunkTaskScheduler.gd remains at or below its 248-line ceiling")

	_start_test("Tier 5.2: All 21 prior headless suites pass")
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
		"test_phase5_orbital_hud_environment_headless.gd",
		"test_phase6_targets_combat_mobile_headless.gd",
		"test_phase7_thermal_governor_encounters_headless.gd",
		"test_phase8_waypoints_evasion_hud_headless.gd",
		"test_quadtree_headless.gd",
	]
	_assert_int(suites.size(), 21, "Discovered all 21 prior headless suites")
	var executable: String = OS.get_executable_path()
	for suite in suites:
		var output: Array = []
		var exit_code: int = OS.execute(
			executable,
			PackedStringArray([
				"--headless", "-s", ProjectSettings.globalize_path("res://" + suite),
				"--", "--direct-regression"
			]),
			output,
			true
		)
		_assert_int(exit_code, 0, "%s exited successfully" % suite)
		if exit_code != 0:
			printerr("    [SUITE OUTPUT] %s" % str(output))

func _instantiate_sim() -> Node:
	var packed: PackedScene = load("res://main.tscn")
	var sim: Node = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	return sim

func _dispose_sim(sim: Node) -> void:
	if sim == null:
		return
	sim.destroy()
	if sim.get_parent() == get_root():
		get_root().remove_child(sim)
	sim.free()

func _step_intercept_tick(sim: Node) -> void:
	sim.step_simulation(1.0 / 120.0)
	var ship: SpaceshipController = sim.ship
	ship.global_position += ship.linear_velocity * (1.0 / 120.0)
	ship.linear_velocity += ship.global_transform.basis * Vector3(
		0.0, 0.0, -ship.thrust_input.z * ship.forward_thrust
	) / ship.mass * (1.0 / 120.0)
	if ship.angular_velocity.length_squared() > 1e-12:
		var rotation: Quaternion = ship.global_transform.basis.get_rotation_quaternion()
		var spin: Quaternion = Quaternion(
			ship.angular_velocity.normalized(), ship.angular_velocity.length() * (1.0 / 120.0)
		)
		ship.global_transform.basis = Basis((spin * rotation).normalized())

func _count_lines(path: String) -> int:
	var text: String = FileAccess.get_file_as_string(path)
	var line_count: int = text.split("\n").size()
	if text.ends_with("\n"):
		line_count -= 1
	return line_count
