extends SceneTree

## Phase 10 headless verification for the flight recorder, missions, and release gate.

const DT: float = 1.0 / 120.0
const PHASE10_SUITE: String = "test_phase10_recorder_mission_release_headless.gd"

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 10 Headless Verification Suite (Tiers 1-4)")
	print("==================================================================")
	await process_frame
	_run_tier_1()
	await _run_tier_2()
	await _run_tier_3()
	await _run_tier_4()
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
	print("PHASE 10 TEST SUITE EXECUTION SUMMARY")
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
	print("\n--- Tier 1: 64-Slot Black-Box Recorder, Rebase, and Restore ---")
	_start_test("Tier 1.1: Fixed storage, wrap-around, and latest-slot selection")
	var recorder: FlightRecorderRingBuffer = FlightRecorderRingBuffer.new()
	_assert_int(recorder.CAPACITY, 64, "Recorder capacity is 64")
	_assert_int(recorder.positions.size(), 64, "Positions are preallocated")
	_assert_int(recorder.velocities.size(), 64, "Velocities are preallocated")
	_assert_int(recorder.g_loads.size(), 64, "G-loads are preallocated")
	_assert_int(recorder.temperatures_k.size(), 64, "Temperatures are preallocated")
	_assert_int(recorder.hull_integrities.size(), 64, "Hull states are preallocated")
	_assert_int(recorder.guidance_modes.size(), 64, "Guidance modes are preallocated")
	_assert(not recorder.recording_enabled, "Recording is disabled by default")
	_assert_int(recorder.get_latest_slot(), -1, "Empty recorder has no latest slot")
	for i in range(70):
		var slot: int = recorder.record_snapshot(
			Vector3(float(i), 2.0, -1.0), Vector3(1.0, 0.0, 0.0),
			float(i), 250.0 + float(i), 100.0 - float(i), i
		)
		_assert_int(slot, i % 64, "Snapshot %d writes the expected ring slot" % i)
	_assert_int(recorder.count, 64, "Count saturates at capacity")
	_assert_int(recorder.total_recorded, 70, "All 70 writes are counted")
	_assert_int(recorder.head, 6, "Head wraps to slot 6")
	_assert_int(recorder.get_latest_slot(), 5, "Latest slot is immediately behind head")
	_assert_vec3(recorder.positions[5], Vector3(69.0, 2.0, -1.0), 0.0,
		"Newest snapshot replaces the oldest slot")
	_assert_int(recorder.guidance_modes[5], 8, "Guidance mode clamps to 8")

	_start_test("Tier 1.2: Automatic sampling respects enablement and interval")
	var telemetry: SimulationTelemetry = SimulationTelemetry.new()
	telemetry.g_load = 3.5
	telemetry.surface_temperature_k = 912.0
	telemetry.hull_integrity = 77.0
	recorder.clear()
	_assert(not recorder.step_recorder(1.0, Vector3.ONE, Vector3.ZERO, telemetry, 4),
		"Disabled recorder rejects automatic samples")
	recorder.recording_enabled = true
	recorder.sample_interval = 0.25
	_assert(not recorder.step_recorder(0.1, Vector3.ONE, Vector3.ZERO, telemetry, 4),
		"Sub-interval step does not sample")
	_assert(recorder.step_recorder(0.15, Vector3(4.0, 5.0, 6.0), Vector3(7.0, 8.0, 9.0),
		telemetry, 4), "Interval crossing records a sample")
	_assert_int(recorder.count, 1, "One automatic sample is stored")
	_assert_int(recorder.total_recorded, 1, "Automatic sample increments total")
	_assert_approx(recorder.time_since_last_sample, 0.0, 1e-6, "Interval remainder resets")
	_assert_approx(recorder.g_loads[0], 3.5, 1e-6, "G-load is copied from telemetry")
	_assert_approx(recorder.temperatures_k[0], 912.0, 1e-6, "Temperature is copied")
	_assert_approx(recorder.hull_integrities[0], 77.0, 1e-6, "Hull integrity is copied")
	_assert_int(recorder.guidance_modes[0], 4, "Guidance mode is copied")
	_assert(not recorder.step_recorder(DT, Vector3.ONE, Vector3.ZERO, null, 4),
		"Null telemetry is rejected")

	_start_test("Tier 1.3: Origin rebase shifts snapshots and restore is exact")
	recorder.clear()
	var saved_pos: Vector3 = Vector3(2_100.0, -350.0, 90.0)
	var saved_vel: Vector3 = Vector3(12.0, -3.0, 44.0)
	var saved_slot: int = recorder.record_snapshot(saved_pos, saved_vel, 2.25, 880.0, 63.0, 8)
	recorder.record_snapshot(Vector3(-500.0, 7.0, 9.0), Vector3.ZERO, 1.0, 300.0, 100.0, 1)
	var offset: Vector3 = Vector3(2_000.0, -250.0, 400.0)
	recorder.rebase_origin(offset)
	_assert_vec3(recorder.positions[saved_slot], saved_pos - offset, 1e-5,
		"Recorded position shifts by -offset")
	_assert_vec3(recorder.velocities[saved_slot], saved_vel, 0.0,
		"Rebase leaves recorded velocity unchanged")
	var ship: SpaceshipController = SpaceshipController.new()
	get_root().add_child(ship)
	ship.global_position = Vector3.ZERO
	ship.linear_velocity = Vector3.ZERO
	var thermal: ThermalStructuralModel = ThermalStructuralModel.new()
	var guidance: FlightGuidanceSystem = FlightGuidanceSystem.new()
	get_root().add_child(guidance)
	_assert(recorder.restore_snapshot(saved_slot, ship, thermal, guidance),
		"Valid snapshot restores successfully")
	_assert_vec3(ship.global_position, saved_pos - offset, 1e-5,
		"Ship position is restored after rebase")
	_assert_vec3(ship.linear_velocity, saved_vel, 1e-6, "Ship velocity is restored")
	_assert_approx(thermal.surface_temperature_k, 880.0, 1e-6, "Thermal temperature is restored")
	_assert_approx(thermal.hull_integrity, 63.0, 1e-6, "Hull integrity is restored")
	_assert_int(guidance.mode, 8, "Guidance mode is restored")
	_assert(not recorder.restore_snapshot(-1, ship), "Negative slot is rejected")
	_assert(not recorder.restore_snapshot(2, ship), "Unwritten slot below capacity is rejected")
	_assert(not recorder.restore_snapshot(64, ship), "Out-of-range slot is rejected")
	_assert(not recorder.restore_snapshot(0, null), "Null ship is rejected")
	get_root().remove_child(guidance)
	guidance.free()
	get_root().remove_child(ship)
	ship.free()

func _run_tier_2() -> void:
	print("\n--- Tier 2: Deterministic Multi-Stage Mission Scenario ---")
	_start_test("Tier 2.1: Recon capture spawns the intercept wave")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.freeze = true
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3.ZERO
	sim.encounter_director.waypoints.clear()
	sim.target_pool.clear()
	sim.encounter_director.auto_spawn_waves = false
	sim.encounter_director.mission.start_mission(
		sim.encounter_director, sim.target_pool, sim.ship.global_position, Vector3.FORWARD
	)
	_assert_int(sim.encounter_director.mission.stage, MissionScenarioRunner.STAGE_WAYPOINT_RECON,
		"Mission starts in reconnaissance")
	_assert_int(sim.encounter_director.waypoints.active_count, 1,
		"Mission creates one recon waypoint")
	_assert_vec3(sim.encounter_director.waypoints.get_current_waypoint_position(),
		Vector3(0.0, 0.0, -300.0), 1e-5, "Recon waypoint lies 300 m forward")
	sim.ship.global_position = sim.encounter_director.waypoints.get_current_waypoint_position()
	sim.step_simulation(DT)
	_assert_int(sim.encounter_director.mission.stage, MissionScenarioRunner.STAGE_ORBITAL_INTERCEPT,
		"Recon capture advances to orbital intercept")
	_assert_int(sim.target_pool.active_count, 2, "Intercept wave spawns two drones")
	_assert(sim.weapon_system.locked_target_id >= 0, "Intercept wave acquires a target lock")
	_assert_int(sim.telemetry.mission_stage, MissionScenarioRunner.STAGE_ORBITAL_INTERCEPT,
		"Mission stage reaches telemetry")

	_start_test("Tier 2.2: Intercept kills advance to soft landing")
	var destroyed: int = 0
	for id in range(TargetPoolManager.POOL_SIZE):
		if sim.target_pool.is_in_use[id]:
			sim.target_pool.apply_damage(id, 1.0e9)
			destroyed += 1
	_assert_int(destroyed, 2, "Both intercept drones are destroyed")
	sim.step_simulation(DT)
	_assert_int(sim.encounter_director.mission.stage, MissionScenarioRunner.STAGE_SOFT_LANDING,
		"Two kills advance to soft landing")

	_start_test("Tier 2.3: Touchdown completes the mission and awards the bonus")
	sim.ship.global_position = sim.planet_manager.planet_center_offset \
		+ Vector3.UP * sim.planet_manager.planet_radius
	sim.ship.linear_velocity = Vector3.ZERO
	sim.step_simulation(DT)
	_assert(sim.telemetry.radar_altitude_agl <= 25.0, "Radar altitude reaches touchdown range")
	_assert(sim.telemetry.total_speed <= 5.0, "Touchdown speed is within the limit")
	_assert_int(sim.encounter_director.mission.stage, MissionScenarioRunner.STAGE_COMPLETED,
		"Touchdown conditions complete the mission")
	_assert_int(sim.telemetry.combat_score, 950,
		"Two kills, one waypoint, and mission bonus total 950")
	_assert_int(sim.hud.displayed_mission_stage, MissionScenarioRunner.STAGE_COMPLETED,
		"HUD mirrors the completed mission stage")
	_assert_int(sim.telemetry.mission_stage, MissionScenarioRunner.STAGE_COMPLETED,
		"Telemetry mirrors the completed mission stage")

	_start_test("Tier 2.4: Hull depletion fails an active mission")
	var failed_sim: Node = _instantiate_sim()
	await process_frame
	failed_sim.ship.process_user_input = false
	failed_sim.floating_origin.rebase_threshold = 1.0e12
	failed_sim.encounter_director.waypoints.clear()
	failed_sim.encounter_director.mission.start_mission(
		failed_sim.encounter_director, failed_sim.target_pool,
		failed_sim.ship.global_position, Vector3.FORWARD
	)
	failed_sim.encounter_director.thermal.hull_integrity = 0.0
	failed_sim.step_simulation(DT)
	_assert_int(failed_sim.encounter_director.mission.stage, MissionScenarioRunner.STAGE_FAILED,
		"Zero hull fails the active mission")
	_assert_int(failed_sim.telemetry.mission_stage, MissionScenarioRunner.STAGE_FAILED,
		"Failure reaches telemetry")
	_dispose_sim(failed_sim)
	_dispose_sim(sim)

func _run_tier_3() -> void:
	print("\n--- Tier 3: 1,000-Tick Full-System Zero Static Growth ---")
	_start_test("Tier 3.1: Recorder, active mission, capacitor, waves, and evasion")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3.ZERO
	sim.encounter_director.waypoints.clear()
	sim.encounter_director.recorder.recording_enabled = true
	sim.encounter_director.mission.start_mission(
		sim.encounter_director, sim.target_pool, sim.ship.global_position, Vector3.FORWARD
	)
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
		"Phase 10 steady state has zero static growth (%d bytes)" % (
			memory_after - memory_before
		))
	_assert(sim.encounter_director.recorder.count > 0, "Recorder captures live samples")
	_assert_int(sim.encounter_director.recorder.count,
		sim.telemetry.recorded_samples, "Recorder count reaches telemetry")
	_assert(sim.encounter_director.mission.stage != MissionScenarioRunner.STAGE_INACTIVE,
		"Mission remains active throughout the run")
	_dispose_sim(sim)

func _run_tier_4() -> void:
	print("\n--- Tier 4: 38-Script Guardrails and 22-Suite Master Regression Gate ---")
	_start_test("Tier 4.1: All 38 production scripts declare class_name and stay <= 250 lines")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert_int(production_files.size(), 38, "Discovered all 38 production scripts")
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = _count_lines("res://" + file)
		_assert(line_count > 0 and line_count <= 250,
			"%s has %d lines (limit 250)" % [file, line_count])
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
	for required in [
		"FlightRecorderRingBuffer.gd", "MissionScenarioRunner.gd", "EncounterDirector.gd",
		"PropellantMassModel.gd", "ProximityWarningSystem.gd",
		"PlanetaryWindModel.gd", "ShipPowerBusModel.gd",
		"LandingGearModel.gd", "RadarOcclusionModel.gd",
		"PlanetarySimulation.gd", "SimulationTelemetry.gd", "CockpitHUD.gd"
	]:
		_assert(production_files.has(required), "%s is a production script" % required)
	_assert(_count_lines("res://PlanetarySimulation.gd") <= 248,
		"PlanetarySimulation.gd remains at or below its 248-line ceiling")
	_assert(_count_lines("res://ChunkTaskScheduler.gd") <= 248,
		"ChunkTaskScheduler.gd remains at or below its 248-line ceiling")
	_assert(_count_lines("res://FlightGuidanceSystem.gd") <= 245,
		"FlightGuidanceSystem.gd remains at or below its 245-line ceiling")
	_assert(_count_lines("res://CockpitHUD.gd") <= 248,
		"CockpitHUD.gd remains at or below its 248-line ceiling")

	_start_test("Tier 4.2: All 22 prior headless suites pass")
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
		"test_phase9_weapon_heat_autopilot_score_headless.gd",
		"test_quadtree_headless.gd",
	]
	_assert_int(suites.size(), 22, "Discovered all 22 prior headless suites")
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

func _count_lines(path: String) -> int:
	var text: String = FileAccess.get_file_as_string(path)
	var line_count: int = text.split("\n").size()
	if text.ends_with("\n"):
		line_count -= 1
	return line_count
