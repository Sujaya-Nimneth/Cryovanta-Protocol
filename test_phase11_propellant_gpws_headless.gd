extends SceneTree

## Phase 11 headless verification for propellant, GPWS, and the release gate.

const DT: float = 1.0 / 120.0

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 11 Headless Verification Suite (Tiers 1-4)")
	print("==================================================================")
	await process_frame
	await _run_tier_1()
	_run_tier_2()
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
	print("PHASE 11 TEST SUITE EXECUTION SUMMARY")
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
	print("\n--- Tier 1: Recorder Slot Guard and Tsiolkovsky Propellant ---")
	_start_test("Tier 1.1: Recorder rejects unwritten slots and synchronizes physics")
	var recorder: FlightRecorderRingBuffer = FlightRecorderRingBuffer.new()
	var ship: SpaceshipController = SpaceshipController.new()
	get_root().add_child(ship)
	ship.freeze = true
	recorder.record_snapshot(Vector3(10.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0), 1.0, 300.0, 100.0, 1)
	_assert(not recorder.restore_snapshot(1, ship), "Unwritten slot one is rejected")
	_assert_int(recorder.count, 1, "Rejected restore does not alter the recorder")
	recorder.record_snapshot(Vector3(20.0, 5.0, 0.0), Vector3(9.0, 1.0, 0.0), 2.0, 400.0, 90.0, 2)
	_assert(recorder.restore_snapshot(1, ship), "Written slot restores in-tree")
	var physics_transform: Transform3D = PhysicsServer3D.body_get_state(
		ship.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM
	)
	var physics_velocity: Vector3 = PhysicsServer3D.body_get_state(
		ship.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY
	)
	_assert_vec3(physics_transform.origin, Vector3(20.0, 5.0, 0.0), 1e-5,
		"PhysicsServer3D transform matches the restored position")
	_assert_vec3(physics_velocity, Vector3(9.0, 1.0, 0.0), 1e-5,
		"PhysicsServer3D linear velocity matches the snapshot")

	_start_test("Tier 1.2: Disabled propellant preserves constant mass")
	var propellant: PropellantMassModel = PropellantMassModel.new()
	ship.mass = 1_337.0
	ship.set_thrust_input(Vector3(0.0, 0.0, 1.0))
	_assert(not propellant.enabled, "Propellant model is disabled by default")
	_assert_approx(propellant.step_propellant(DT, ship), 1_337.0, 0.0,
		"Disabled model returns the unchanged ship mass")
	_assert_approx(ship.mass, 1_337.0, 0.0, "Disabled model leaves ship.mass invariant")
	_assert_approx(propellant.mass_flow_rate, 0.0, 0.0, "Disabled flow rate is zero")
	_assert_approx(propellant.get_fuel_fraction(), 1.0, 0.0, "Default fuel fraction is full")

	_start_test("Tier 1.3: Tsiolkovsky mass flow and wet-mass synchronization")
	propellant.enabled = true
	ship.mass = propellant.get_wet_mass()
	ship.set_thrust_input(Vector3(0.0, 0.0, 1.0))
	var before_propellant: float = propellant.propellant_mass
	var expected_flow: float = ship.forward_thrust / (
		propellant.specific_impulse_s * PropellantMassModel.STANDARD_GRAVITY
	)
	var wet_mass: float = propellant.step_propellant(DT, ship)
	_assert_approx(propellant.mass_flow_rate, expected_flow, 1e-6,
		"Mass flow equals thrust divided by exhaust velocity")
	_assert_approx(propellant.propellant_mass, before_propellant - expected_flow * DT, 1e-6,
		"Propellant decreases by mass flow times delta")
	_assert_approx(wet_mass, propellant.dry_mass + propellant.propellant_mass, 1e-4,
		"Wet mass equals dry mass plus remaining propellant")
	_assert_approx(ship.mass, wet_mass, 1e-6, "Ship mass follows wet mass")
	_assert_approx(propellant.get_remaining_delta_v(),
		propellant.specific_impulse_s * PropellantMassModel.STANDARD_GRAVITY
			* log(propellant.get_wet_mass() / propellant.dry_mass),
		1e-5, "Remaining delta-v matches the Tsiolkovsky equation")

	_start_test("Tier 1.4: Depletion clamps dry mass and cuts thrust")
	propellant.propellant_mass = 0.001
	ship.set_thrust_input(Vector3(0.0, 0.0, 1.0))
	propellant.step_propellant(1.0, ship)
	_assert(propellant.fuel_depleted, "Zero propellant sets the depletion latch")
	_assert_approx(propellant.propellant_mass, 0.0, 0.0, "Propellant cannot go negative")
	_assert_approx(ship.mass, propellant.dry_mass, 0.0, "Depleted ship mass equals dry mass")
	_assert_vec3(ship.thrust_input, Vector3.ZERO, 0.0, "Depletion zeroes thrust input")
	_assert(ship.thrust_cutoff, "Depletion latches the controller cutoff")
	_assert_approx(propellant.get_remaining_delta_v(), 0.0, 0.0, "Dry ship has no delta-v")
	propellant.reset(ship)
	_assert(not propellant.fuel_depleted, "Reset clears the depletion latch")
	_assert(not ship.thrust_cutoff, "Reset releases the controller cutoff")
	get_root().remove_child(ship)
	ship.free()

func _run_tier_2() -> void:
	print("\n--- Tier 2: GPWS Terrain and Target Threat Alerts ---")
	_start_test("Tier 2.1: Safe level flight produces no alert")
	var warning: ProximityWarningSystem = ProximityWarningSystem.new()
	_assert_int(warning.evaluate_proximity(1_000.0, 0.0, Vector3.ZERO),
		ProximityWarningSystem.ALERT_NONE, "Safe level flight is clear")
	_assert(warning.time_to_impact == INF, "Level flight has infinite impact time")

	_start_test("Tier 2.2: Moderate and steep descent escalate alerts")
	_assert_int(warning.evaluate_proximity(300.0, -50.0, Vector3.ZERO),
		ProximityWarningSystem.ALERT_CAUTION, "Six-second impact is a caution")
	_assert_approx(warning.time_to_impact, 6.0, 1e-6, "Caution TTI is six seconds")
	_assert_int(warning.evaluate_proximity(150.0, -60.0, Vector3.ZERO),
		ProximityWarningSystem.ALERT_PULL_UP, "Two-and-a-half-second impact is pull-up")
	_assert_approx(warning.time_to_impact, 2.5, 1e-6, "Pull-up TTI is 2.5 seconds")

	_start_test("Tier 2.3: Nearby active target elevates clear airspace")
	var targets: TargetPoolManager = TargetPoolManager.new()
	get_root().add_child(targets)
	var target_id: int = targets.spawn_target(Vector3(100.0, 0.0, 0.0), Vector3.ZERO, 100.0)
	_assert(target_id >= 0, "Threat target occupies a pool slot")
	_assert_int(warning.evaluate_proximity(1_000.0, 0.0, Vector3.ZERO, targets),
		ProximityWarningSystem.ALERT_CAUTION, "Threat inside 250 m elevates to caution")
	_assert(warning.threat_active, "Nearby target marks the threat active")
	_assert_approx(warning.nearest_threat_distance, 100.0, 1e-6, "Nearest threat distance is 100 m")
	targets.clear()
	_assert_int(warning.evaluate_proximity(1_000.0, 0.0, Vector3.ZERO, targets),
		ProximityWarningSystem.ALERT_NONE, "Clearing targets restores a clear alert")
	_assert(not warning.threat_active, "Cleared pool has no active threat")
	get_root().remove_child(targets)
	targets.free()

func _run_tier_3() -> void:
	print("\n--- Tier 3: Live Telemetry, HUD Sync, and Zero Static Growth ---")
	_start_test("Tier 3.1: Propellant and proximity registers update in lockstep")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.freeze = true
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3(0.0, -60.0, 0.0)
	sim.encounter_director.waypoints.clear()
	sim.encounter_director.propellant.enabled = true
	sim.target_pool.clear()
	sim.target_pool.spawn_target(Vector3(100.0, 0.0, 0.0), Vector3.ZERO, 100.0)
	sim.ship.set_thrust_input(Vector3(0.0, 0.0, 1.0))
	sim.step_simulation(DT)
	_assert_approx(sim.telemetry.fuel_fraction,
		sim.encounter_director.propellant.get_fuel_fraction(), 1e-9,
		"Telemetry fuel fraction mirrors the model")
	_assert_approx(sim.telemetry.remaining_delta_v,
		sim.encounter_director.propellant.get_remaining_delta_v(), 1e-9,
		"Telemetry delta-v mirrors the model")
	_assert_int(sim.telemetry.proximity_alert,
		sim.encounter_director.proximity.alert_level, "Telemetry alert mirrors GPWS")
	_assert_approx(sim.telemetry.time_to_impact,
		sim.encounter_director.proximity.time_to_impact, 0.0,
		"Telemetry impact time mirrors GPWS")
	_assert_approx(sim.hud.displayed_fuel_fraction, sim.telemetry.fuel_fraction, 0.0,
		"HUD fuel fraction mirrors telemetry")
	_assert_int(sim.hud.displayed_proximity_alert, sim.telemetry.proximity_alert,
		"HUD proximity alert mirrors telemetry")
	_start_test("Tier 3.2: Depleted live ticks reject guidance thrust and apply zero thruster force")
	sim.encounter_director.propellant.propellant_mass = 0.0
	sim.encounter_director.propellant.fuel_depleted = true
	sim.ship.thrust_cutoff = true
	sim.guidance.set_waypoint_target(true, Vector3(0.0, 0.0, -1_000.0))
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_WAYPOINT_INTERCEPT)
	sim.step_simulation(DT)
	_assert(sim.ship.thrust_cutoff, "First live tick keeps the depletion cutoff latched")
	_assert_vec3(sim.ship.thrust_input, Vector3.ZERO, 0.0,
		"First live tick strips autopilot thrust input")
	_assert_vec3(sim.ship.get_current_net_force() - sim.ship.get_current_gravity(),
		sim.ship.get_current_drag(), 1e-4, "First live tick has no thruster force")
	sim.ship.set_thrust_input(Vector3(1.0, 1.0, 1.0))
	sim.step_simulation(DT)
	_assert(sim.ship.thrust_cutoff, "Second live tick keeps the depletion cutoff latched")
	_assert_vec3(sim.ship.thrust_input, Vector3.ZERO, 0.0,
		"Second live tick rejects direct thrust writes")
	_assert_vec3(sim.ship.get_current_net_force() - sim.ship.get_current_gravity(),
		sim.ship.get_current_drag(), 1e-4, "Second live tick has no thruster force")

	_start_test("Tier 3.3: 1,000 ticks with all active systems have zero static growth")
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
		"Phase 11 steady state has zero static growth (%d bytes)" % (
			memory_after - memory_before
		))
	_assert(sim.telemetry.fuel_fraction >= 0.0 and sim.telemetry.fuel_fraction <= 1.0,
		"Fuel fraction remains bounded")
	_assert(sim.encounter_director.recorder.count > 0, "Recorder remains active")
	_assert(sim.encounter_director.mission.stage != MissionScenarioRunner.STAGE_INACTIVE,
		"Mission remains active")
	_dispose_sim(sim)

func _run_tier_4() -> void:
	print("\n--- Tier 4: 38-Script Guardrails and 23-Suite Master Regression Gate ---")
	_start_test("Tier 4.1: All 38 production scripts declare class_name and stay <= 250 lines")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert(production_files.size() >= 38,
		"Discovered all 38 Phase 11 production scripts (found %d)" % production_files.size())
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = _count_lines("res://" + file)
		_assert(line_count > 0 and line_count <= 250,
			"%s has %d lines (limit 250)" % [file, line_count])
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
	for required in [
		"PropellantMassModel.gd", "ProximityWarningSystem.gd", "EncounterDirector.gd",
		"FlightRecorderRingBuffer.gd", "PlanetaryWindModel.gd", "ShipPowerBusModel.gd",
		"LandingGearModel.gd", "RadarOcclusionModel.gd",
		"SimulationTelemetry.gd", "CockpitHUD.gd"
	]:
		_assert(production_files.has(required), "%s is a production script" % required)
	_assert(_count_lines("res://PlanetarySimulation.gd") <= 248,
		"PlanetarySimulation.gd remains at or below 248 lines")
	_assert(_count_lines("res://ChunkTaskScheduler.gd") <= 248,
		"ChunkTaskScheduler.gd remains at or below 248 lines")
	_assert(_count_lines("res://FlightGuidanceSystem.gd") <= 245,
		"FlightGuidanceSystem.gd remains at or below 245 lines")
	_assert(_count_lines("res://CockpitHUD.gd") <= 248,
		"CockpitHUD.gd remains at or below 248 lines")
	_assert(_count_lines("res://EncounterDirector.gd") <= 248,
		"EncounterDirector.gd remains at or below 248 lines")

	if OS.get_cmdline_user_args().has("--direct-regression"):
		return
	_start_test("Tier 4.2: All 23 prior headless suites pass")
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
		"test_phase10_recorder_mission_release_headless.gd",
		"test_quadtree_headless.gd",
	]
	_assert_int(suites.size(), 23, "Discovered all 23 prior headless suites")
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
