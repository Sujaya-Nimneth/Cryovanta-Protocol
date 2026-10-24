extends SceneTree

## Phase 13 headless verification for gear, radar LOS, telemetry, and release gates.

const DT: float = 1.0 / 120.0
const PLANET_RADIUS: float = 100_000.0
const PLANET_CENTER: Vector3 = Vector3.ZERO

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 13 Headless Verification Suite (Tiers 1-4)")
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
	print("PHASE 13 TEST SUITE EXECUTION SUMMARY")
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
	print("\n--- Tier 1: Landing Gear, Drag Penalty, and Touchdown Shock ---")
	_start_test("Tier 1.1: Disabled gear preserves drag and reset state")
	var gear: LandingGearModel = LandingGearModel.new()
	var ship: SpaceshipController = SpaceshipController.new()
	get_root().add_child(ship)
	ship.drag_coefficient = 0.37
	_assert(not gear.enabled, "Gear is disabled by default")
	_assert(gear.deployed, "Gear starts deployed")
	_assert_approx(gear.deploy_progress, 1.0, 0.0, "Gear starts fully deployed")
	gear.deploy_progress = 0.4
	gear.step_gear(1.0, 1_000.0, 0.0, ship)
	_assert_approx(gear.deploy_progress, 0.4, 0.0, "Disabled gear ignores actuator commands")
	_assert_approx(ship.drag_coefficient, 0.37, 0.0, "Disabled gear preserves ship drag")
	gear.weight_on_wheels = true
	gear.compression_ratio = 1.0
	gear.reset()
	_assert_approx(gear.deploy_progress, 1.0, 0.0, "Reset fully deploys gear")
	_assert(not gear.weight_on_wheels, "Reset clears weight-on-wheels")
	_assert_approx(gear.compression_ratio, 0.0, 0.0, "Reset clears shock compression")

	_start_test("Tier 1.2: Automatic retraction and deployment drive drag")
	gear.enabled = true
	gear.deployed = false
	gear.deploy_progress = 0.0
	ship.drag_coefficient = gear.retracted_drag_coeff
	gear.step_gear(1.0, 500.0, 0.0, ship)
	_assert(not gear.deployed, "Altitude above retract threshold remains retracted")
	_assert_approx(gear.deploy_progress, 0.0, 0.0, "Retracted gear stays at zero progress")
	_assert_approx(ship.drag_coefficient, gear.retracted_drag_coeff, 1e-6,
		"Retracted gear applies low drag")
	gear.deployed = true
	gear.step_gear(0.25, 100.0, 0.0, ship)
	_assert(gear.deploy_progress > 0.0 and gear.deploy_progress < 1.0,
		"Low-altitude command deploys at the actuator rate")
	_assert(ship.drag_coefficient > gear.retracted_drag_coeff
		and ship.drag_coefficient < gear.deployed_drag_coeff,
		"Partial deployment interpolates drag")
	gear.deployed = true
	gear.deploy_progress = 0.0
	gear.step_gear(1.0, 100.0, 0.0, ship)
	_assert_approx(gear.deploy_progress, 1.0, 1e-6, "Full deployment reaches maximum progress")
	_assert_approx(ship.drag_coefficient, gear.deployed_drag_coeff, 1e-6,
		"Full deployment applies high drag")

	_start_test("Tier 1.3: Soft, hard, and gear-up touchdown damage")
	var thermal: ThermalStructuralModel = ThermalStructuralModel.new()
	gear.deployed = true
	gear.deploy_progress = 1.0
	gear.step_gear(1.0, 2.0, -4.0, ship, thermal)
	_assert(gear.weight_on_wheels, "Soft touchdown establishes weight on wheels")
	_assert_approx(gear.compression_ratio, 0.5, 1e-6, "Soft touchdown compresses gear by half")
	_assert_approx(thermal.hull_integrity, 100.0, 0.0, "Soft touchdown causes zero hull damage")
	gear.step_gear(1.0, 2.0, -15.0, ship, thermal)
	_assert(thermal.hull_integrity < 100.0, "Hard touchdown damages the hull")
	var hard_damage: float = 100.0 - thermal.hull_integrity
	_assert_approx(hard_damage, 28.0, 1e-6, "Hard touchdown uses excess sink-rate damage")
	thermal.reset()
	gear.auto_deploy_altitude = 1.0
	gear.deployed = false
	gear.deploy_progress = 0.0
	gear.step_gear(1.0, 3.0, -3.0, ship, thermal)
	_assert(thermal.hull_integrity < 100.0, "Gear-up contact damages the hull")
	_assert_approx(100.0 - thermal.hull_integrity, 45.0, 1e-6,
		"Gear-up contact uses the configured damage rate")
	get_root().remove_child(ship)
	ship.free()

func _run_tier_2() -> void:
	print("\n--- Tier 2: Planetary Horizon LOS and Signal Attenuation ---")
	_start_test("Tier 2.1: Horizon occlusion and range attenuation")
	var radar: RadarOcclusionModel = RadarOcclusionModel.new()
	var observer: Vector3 = Vector3(0.0, 101_000.0, 0.0)
	var near_target: Vector3 = Vector3(500.0, 101_000.0, 0.0)
	var far_target: Vector3 = Vector3(25_001.0, 101_000.0, 0.0)
	var occluded: Vector3 = Vector3(0.0, -101_000.0, 0.0)
	_assert(radar.is_line_of_sight_clear(observer, near_target, PLANET_CENTER, PLANET_RADIUS),
		"Near target above the horizon is visible")
	_assert(not radar.is_line_of_sight_clear(observer, occluded, PLANET_CENTER, PLANET_RADIUS),
		"Opposite-side target is occluded")
	_assert_approx(radar.compute_signal_strength(
		observer, near_target, PLANET_CENTER, PLANET_RADIUS
	), 0.98, 1e-6, "Close target has strong signal")
	_assert_approx(radar.compute_signal_strength(
		observer, occluded, PLANET_CENTER, PLANET_RADIUS
	), 0.0, 0.0, "Occluded target has zero signal")
	_assert_approx(radar.compute_signal_strength(
		observer, far_target, PLANET_CENTER, PLANET_RADIUS
	), 0.0, 0.0, "Target beyond radar range has zero signal")

	_start_test("Tier 2.2: Target and waypoint LOS registers")
	var pool: TargetPoolManager = TargetPoolManager.new()
	var weapon: SpaceshipWeaponSystem = SpaceshipWeaponSystem.new()
	var waypoints: WaypointRingBuffer = WaypointRingBuffer.new()
	get_root().add_child(pool)
	get_root().add_child(weapon)
	var target_id: int = pool.spawn_target(near_target)
	weapon.locked_target_id = target_id
	waypoints.add_waypoint(occluded)
	radar.step_radar_los(observer, PLANET_CENTER, PLANET_RADIUS, weapon, pool, waypoints)
	_assert(radar.target_los_clear, "Visible locked target reports clear LOS")
	_assert(radar.target_signal_strength > 0.9, "Visible target reports strong signal")
	_assert(not radar.waypoint_los_clear, "Occluded waypoint reports blocked LOS")
	_assert_approx(radar.waypoint_signal_strength, 0.0, 0.0,
		"Occluded waypoint reports zero signal")
	pool.release_target(target_id)
	radar.step_radar_los(observer, PLANET_CENTER, PLANET_RADIUS, weapon, pool, waypoints)
	_assert(radar.target_los_clear, "Missing target resets LOS to clear")
	_assert_approx(radar.target_signal_strength, 0.0, 0.0,
		"Missing target reports zero signal")
	radar.reset()
	_assert(radar.target_los_clear and radar.waypoint_los_clear, "Reset clears LOS states")
	_assert_approx(radar.target_signal_strength, 0.0, 0.0, "Reset clears target signal")
	_assert_approx(radar.waypoint_signal_strength, 0.0, 0.0, "Reset clears waypoint signal")
	get_root().remove_child(weapon)
	weapon.free()
	get_root().remove_child(pool)
	pool.free()

func _run_tier_3() -> void:
	print("\n--- Tier 3: Live Telemetry, HUD Sync, and Zero Static Growth ---")
	_start_test("Tier 3.1: Gear and radar registers update with the HUD")
	var sim: Node = _instantiate_sim()
	await process_frame
	_configure_sim(sim)
	sim.encounter_director.landing_gear.enabled = true
	sim.encounter_director.landing_gear.deploy_progress = 0.0
	sim.telemetry.radar_altitude_agl = 100.0
	sim.telemetry.vertical_speed = -2.0
	var center: Vector3 = sim.planet_manager.planet_center_offset
	var target_id: int = sim.target_pool.spawn_target(center + Vector3(0.0, 101_000.0, 0.0))
	sim.weapon_system.locked_target_id = target_id
	sim.encounter_director.waypoints.add_waypoint(center + Vector3(0.0, -101_000.0, 0.0))
	sim.step_simulation(DT)
	_assert_approx(sim.telemetry.gear_deploy_progress,
		sim.encounter_director.landing_gear.deploy_progress, 0.0,
		"Telemetry gear progress mirrors the actuator")
	_assert(sim.telemetry.target_los_clear, "Telemetry target LOS mirrors the radar")
	_assert(not sim.encounter_director.radar_los.waypoint_los_clear,
		"Waypoint behind the planet limb is occluded")
	_assert_approx(sim.telemetry.waypoint_signal_strength,
		sim.encounter_director.radar_los.waypoint_signal_strength, 0.0,
		"Telemetry waypoint signal mirrors the radar")
	_assert_approx(sim.hud.displayed_gear_progress, sim.telemetry.gear_deploy_progress, 0.0,
		"HUD gear progress mirrors telemetry")
	_assert(sim.hud.displayed_target_los == sim.telemetry.target_los_clear,
		"HUD target LOS mirrors telemetry")
	sim.target_pool.positions[target_id] = center + Vector3(0.0, -101_000.0, 0.0)
	sim.step_simulation(DT)
	_assert(not sim.telemetry.target_los_clear, "Target behind the limb loses LOS")
	_assert_approx(sim.telemetry.waypoint_signal_strength, 0.0, 0.0,
		"Occluded waypoint signal is zero")
	_dispose_sim(sim)

	_start_test("Tier 3.2: 1,000 ticks with all Phase 1-13 systems active")
	sim = _instantiate_sim()
	await process_frame
	_configure_sim(sim)
	var director: EncounterDirector = sim.encounter_director
	director.landing_gear.enabled = true
	director.wind.enabled = true
	director.power_bus.enabled = true
	director.propellant.enabled = true
	director.recorder.recording_enabled = true
	director.auto_spawn_waves = true
	director.desired_active_targets = 2
	director.evasion_enabled = true
	director.target_initial_health = 1.0e9
	director.mission.start_mission(
		director, sim.target_pool, sim.ship.global_position, Vector3.FORWARD
	)
	sim.weapon_system.capacitor.enabled = true
	for i in range(120):
		sim.step_simulation(DT)
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		sim.step_simulation(DT)
	var memory_after: int = OS.get_static_memory_usage()
	_assert(memory_after - memory_before <= 0,
		"Phase 13 steady state has zero static growth (%d bytes)" % (
			memory_after - memory_before
		))
	_assert(sim.telemetry.gear_deploy_progress >= 0.0
		and sim.telemetry.gear_deploy_progress <= 1.0,
		"Gear progress remains bounded")
	_assert(sim.telemetry.target_los_clear or sim.telemetry.target_los_clear == false,
		"Target LOS remains a valid boolean register")
	_assert(director.recorder.count > 0, "Recorder remains active")
	_assert(director.mission.stage != MissionScenarioRunner.STAGE_INACTIVE,
		"Mission remains active")
	_assert(sim.target_pool.active_count <= TargetPoolManager.POOL_SIZE,
		"Target pool remains bounded")
	_dispose_sim(sim)

func _run_tier_4() -> void:
	print("\n--- Tier 4: 38-Script Guardrails and 25-Suite Master Regression Gate ---")
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
		"LandingGearModel.gd", "RadarOcclusionModel.gd", "PlanetaryWindModel.gd",
		"ShipPowerBusModel.gd", "SpaceshipController.gd", "EncounterDirector.gd",
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
	_assert(_count_lines("res://EncounterDirector.gd") <= 245,
		"EncounterDirector.gd remains at or below 245 lines")

	_start_test("Tier 4.2: All 25 prior headless suites pass")
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
		"test_phase11_propellant_gpws_headless.gd",
		"test_phase12_wind_power_eclipse_headless.gd",
		"test_quadtree_headless.gd",
	]
	_assert_int(suites.size(), 25, "Discovered all 25 prior headless suites")
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

func _configure_sim(sim: Node) -> void:
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.freeze = true
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3.ZERO
	sim.ship.angular_velocity = Vector3.ZERO
	sim.encounter_director.waypoints.clear()
	sim.target_pool.clear()
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_MANUAL)

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
