extends SceneTree

## Phase 12 headless verification for wind, drag, solar power, and release gates.

const DT: float = 1.0 / 120.0
const PLANET_RADIUS: float = 100_000.0
const ATMOSPHERE_CEILING: float = 10_000.0
const PLANET_CENTER: Vector3 = Vector3.ZERO

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 12 Headless Verification Suite (Tiers 1-4)")
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
	print("PHASE 12 TEST SUITE EXECUTION SUMMARY")
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
	print("\n--- Tier 1: Planetary Wind and Air-Relative Drag ---")
	_start_test("Tier 1.1: Disabled wind is exactly zero and reset clears state")
	var wind: PlanetaryWindModel = PlanetaryWindModel.new()
	_assert(not wind.enabled, "Wind is disabled by default")
	_assert_vec3(
		wind.sample_wind(DT, _at_altitude(3500.0), PLANET_CENTER, PLANET_RADIUS, ATMOSPHERE_CEILING),
		Vector3.ZERO, 0.0, "Disabled wind returns an exact zero vector"
	)
	_assert_approx(wind.current_wind_speed, 0.0, 0.0, "Disabled wind speed is zero")
	wind.reset()
	_assert_approx(wind.elapsed_time, 0.0, 0.0, "Reset clears elapsed time")
	_assert_vec3(wind.current_wind_velocity, Vector3.ZERO, 0.0,
		"Reset clears the cached wind velocity")

	_start_test("Tier 1.2: Jetstream band and atmosphere ceiling")
	wind.enabled = true
	wind.reset()
	var band_wind: Vector3 = wind.sample_wind(
		DT, _at_altitude(3500.0), PLANET_CENTER, PLANET_RADIUS, ATMOSPHERE_CEILING
	)
	_assert(band_wind.length_squared() > 0.0, "Enabled wind is non-zero at the jetstream peak")
	_assert_approx(wind.current_wind_speed, band_wind.length(), 0.0,
		"Cached wind speed matches the sampled vector")
	_assert(band_wind.length() < wind.base_jetstream_speed + wind.turbulence_amplitude,
		"Wind speed stays inside the configured envelope")
	_assert_vec3(
		wind.sample_wind(DT, _at_altitude(ATMOSPHERE_CEILING), PLANET_CENTER,
			PLANET_RADIUS, ATMOSPHERE_CEILING),
		Vector3.ZERO, 0.0, "Wind is exactly zero at the atmosphere ceiling"
	)
	_assert_vec3(
		wind.sample_wind(DT, _at_altitude(ATMOSPHERE_CEILING + 0.001), PLANET_CENTER,
			PLANET_RADIUS, ATMOSPHERE_CEILING),
		Vector3.ZERO, 0.0, "Wind remains zero above the atmosphere ceiling"
	)
	_assert_vec3(
		wind.sample_wind(DT, PLANET_CENTER, PLANET_CENTER, PLANET_RADIUS, ATMOSPHERE_CEILING),
		Vector3.ZERO, 0.0, "Planet-center singularity returns zero wind"
	)
	wind.reset()
	var deterministic_a: Vector3 = wind.sample_wind(
		DT, _at_altitude(3500.0), PLANET_CENTER, PLANET_RADIUS, ATMOSPHERE_CEILING
	)
	wind.reset()
	var deterministic_b: Vector3 = wind.sample_wind(
		DT, _at_altitude(3500.0), PLANET_CENTER, PLANET_RADIUS, ATMOSPHERE_CEILING
	)
	_assert_vec3(deterministic_b, deterministic_a, 0.0, "Wind sampling is deterministic")

	_start_test("Tier 1.3: Stationary ship in a headwind receives opposing drag")
	var ship: SpaceshipController = SpaceshipController.new()
	get_root().add_child(ship)
	ship.freeze = true
	ship.planet_manager = null
	ship.planet_position = PLANET_CENTER
	ship.planet_radius = PLANET_RADIUS
	ship.atmosphere_ceiling = ATMOSPHERE_CEILING
	ship.global_transform = Transform3D(Basis.IDENTITY, _at_altitude(3500.0))
	ship.linear_velocity = Vector3.ZERO
	ship.ambient_wind_velocity = Vector3(40.0, 0.0, 0.0)
	ship._apply_flight_forces()
	var relative_air: Vector3 = ship.linear_velocity - ship.ambient_wind_velocity
	var expected_drag: Vector3 = AtmosphereMath.calculate_drag_force(
		relative_air, ship.get_current_density(), ship.drag_coefficient, ship.cross_sectional_area
	)
	_assert(ship.get_current_drag().length() > 0.0, "Stationary ship in wind has non-zero drag")
	_assert(ship.get_current_drag().dot(relative_air) < 0.0,
		"Drag opposes the air-relative airflow")
	_assert(ship.get_current_drag().x > 0.0, "Headwind drag points opposite the wind")
	_assert_vec3(ship.get_current_drag(), expected_drag, 1e-5,
		"Drag equals the air-relative aerodynamic formula")
	ship.ambient_wind_velocity = Vector3.ZERO
	ship.linear_velocity = Vector3.ZERO
	ship._apply_flight_forces()
	_assert_vec3(ship.get_current_drag(), Vector3.ZERO, 0.0,
		"Zero wind preserves the legacy stationary-ship drag result")
	get_root().remove_child(ship)
	ship.free()

func _run_tier_2() -> void:
	print("\n--- Tier 2: Solar Power Bus, Eclipse, and Brownout ---")
	_start_test("Tier 2.1: Cylindrical eclipse shadow and disabled invariance")
	var bus: ShipPowerBusModel = ShipPowerBusModel.new()
	_assert(not bus.enabled, "Power bus is disabled by default")
	_assert_approx(bus.get_battery_fraction(), 1.0, 0.0, "Default battery is full")
	_assert(not bus.is_position_in_eclipse(
		Vector3(0.0, 105_000.0, 0.0), PLANET_CENTER, PLANET_RADIUS
	), "Sunlit hemisphere is not in eclipse")
	_assert(bus.is_position_in_eclipse(
		Vector3(0.0, -105_000.0, 0.0), PLANET_CENTER, PLANET_RADIUS
	), "Position behind the planet is in eclipse")
	_assert(not bus.is_position_in_eclipse(
		Vector3(100_001.0, -105_000.0, 0.0), PLANET_CENTER, PLANET_RADIUS
	), "Position outside the shadow cylinder is sunlit")
	var disabled_battery: float = bus.battery_wh
	_assert_approx(bus.step_power_bus(
		DT, Vector3(0.0, -105_000.0, 0.0), PLANET_CENTER, PLANET_RADIUS, 1.0, 1.0
	), 1.0, 0.0, "Disabled bus returns the unchanged battery fraction")
	_assert_approx(bus.battery_wh, disabled_battery, 0.0,
		"Disabled bus does not discharge")
	_assert_approx(bus.net_power_rate, 0.0, 0.0, "Disabled bus reports zero net power")
	_assert(not bus.brownout, "Disabled bus clears brownout")

	_start_test("Tier 2.2: Eclipse load drains and sunlit idle generation recharges")
	bus.enabled = true
	bus.reset()
	bus.battery_wh = 100.0
	bus.step_power_bus(
		1.0, Vector3(0.0, -105_000.0, 0.0), PLANET_CENTER, PLANET_RADIUS, 1.0, 1.0
	)
	_assert(bus.in_eclipse, "Shadowed step latches eclipse telemetry")
	_assert(bus.net_power_rate < 0.0, "Eclipse under full load has negative net power")
	_assert_approx(bus.net_power_rate, -40.0, 1e-6,
		"Eclipse net power equals load drain")
	_assert_approx(bus.battery_wh, 60.0, 1e-6, "Eclipse load discharges the battery")
	var drained_fraction: float = bus.get_battery_fraction()
	bus.step_power_bus(
		1.0, Vector3(0.0, 105_000.0, 0.0), PLANET_CENTER, PLANET_RADIUS, 0.0, 0.0
	)
	_assert(not bus.in_eclipse, "Sunlit step clears eclipse")
	_assert(bus.net_power_rate > 0.0, "Sunlit idle generation has positive net power")
	_assert_approx(bus.net_power_rate, 29.0, 1e-6,
		"Sunlit idle net power equals charge minus avionics")
	_assert(bus.get_battery_fraction() > drained_fraction, "Sunlit idle step recharges the battery")

	_start_test("Tier 2.3: Brownout latches the weapon capacitor and blocks firing")
	var capacitor: WeaponHeatCapacitor = WeaponHeatCapacitor.new()
	capacitor.enabled = true
	bus.battery_wh = 0.0
	bus.step_power_bus(
		DT, Vector3(0.0, -105_000.0, 0.0), PLANET_CENTER, PLANET_RADIUS, 1.0, 0.0, capacitor
	)
	_assert_approx(bus.battery_wh, 0.0, 0.0, "Battery clamps at zero")
	_assert(bus.brownout, "Empty battery latches brownout")
	_assert(capacitor.overheated, "Brownout latches the capacitor overheat gate")
	_assert(capacitor.cooldown_remaining >= capacitor.fire_interval,
		"Brownout enforces a full weapon cooldown")
	var ship: SpaceshipController = SpaceshipController.new()
	var pool: ProjectilePoolManager = ProjectilePoolManager.new()
	var weapon: SpaceshipWeaponSystem = SpaceshipWeaponSystem.new()
	get_root().add_child(ship)
	get_root().add_child(pool)
	get_root().add_child(weapon)
	weapon.ship = ship
	weapon.projectile_pool = pool
	weapon.capacitor = capacitor
	_assert_int(weapon.fire_projectile(), -1, "Brownout blocks weapon firing")
	_assert_int(pool.active_count, 0, "Blocked shot spawns no projectile")
	capacitor.heat = 0.0
	bus.step_power_bus(
		1.0, Vector3(0.0, 105_000.0, 0.0), PLANET_CENTER, PLANET_RADIUS, 0.0, 0.0, capacitor
	)
	_assert(not bus.brownout, "Sunlit recharge clears brownout")
	_assert(bus.battery_wh > 0.0, "Sunlit recharge restores battery energy")
	_assert(not capacitor.overheated, "Cool capacitor overheat lock clears after recharge")
	_assert(not bus._brownout_locked_weapon, "Recharge clears the brownout weapon lock latch")
	get_root().remove_child(weapon)
	weapon.free()
	get_root().remove_child(pool)
	pool.free()
	get_root().remove_child(ship)
	ship.free()
	bus.reset()
	_assert_approx(bus.get_battery_fraction(), 1.0, 0.0, "Reset restores a full battery")
	_assert(not bus.in_eclipse and not bus.brownout, "Reset clears eclipse and brownout")

func _run_tier_3() -> void:
	print("\n--- Tier 3: Live Telemetry, HUD Sync, and Zero Static Growth ---")
	_start_test("Tier 3.1: Wind and power registers update with the HUD")
	var sim: Node = _instantiate_sim()
	await process_frame
	_configure_sim(sim)
	sim.encounter_director.wind.enabled = true
	sim.encounter_director.power_bus.enabled = true
	sim.encounter_director.power_bus.sun_direction = Vector3.DOWN
	sim.step_simulation(DT)
	_assert(sim.telemetry.wind_speed > 0.0, "Live telemetry reports atmospheric wind")
	_assert_approx(sim.telemetry.wind_speed,
		sim.encounter_director.wind.current_wind_speed, 0.0,
		"Telemetry wind speed mirrors the wind model")
	_assert_approx(sim.telemetry.battery_fraction,
		sim.encounter_director.power_bus.get_battery_fraction(), 0.0,
		"Telemetry battery fraction mirrors the power bus")
	_assert(sim.telemetry.in_eclipse == sim.encounter_director.power_bus.in_eclipse,
		"Telemetry eclipse state mirrors the power bus")
	_assert(sim.telemetry.power_brownout == sim.encounter_director.power_bus.brownout,
		"Telemetry brownout state mirrors the power bus")
	_assert_approx(sim.hud.displayed_wind_speed, sim.telemetry.wind_speed, 0.0,
		"HUD wind speed mirrors telemetry")
	_assert_approx(sim.hud.displayed_battery_fraction, sim.telemetry.battery_fraction, 0.0,
		"HUD battery fraction mirrors telemetry")
	_assert(sim.telemetry.in_eclipse, "Live shadowed step reports eclipse in telemetry")
	_assert(sim.hud.displayed_battery_fraction == sim.telemetry.battery_fraction,
		"HUD stays synchronized through eclipse state changes")
	sim.encounter_director.power_bus.sun_direction = Vector3.UP
	sim.step_simulation(DT)
	_assert(not sim.telemetry.in_eclipse, "Live sunlit step clears eclipse telemetry")
	_dispose_sim(sim)

	_start_test("Tier 3.2: Headwind raises air-relative convective heating")
	var calm_sim: Node = _instantiate_sim()
	var windy_sim: Node = _instantiate_sim()
	await process_frame
	_configure_sim(calm_sim)
	_configure_sim(windy_sim)
	calm_sim.ship.linear_velocity = Vector3(0.0, 0.0, -1_000.0)
	windy_sim.ship.linear_velocity = Vector3(0.0, 0.0, -1_000.0)
	calm_sim.encounter_director.wind.enabled = false
	windy_sim.encounter_director.wind.enabled = true
	calm_sim.step_simulation(DT)
	windy_sim.step_simulation(DT)
	_assert(windy_sim.encounter_director.wind.current_wind_speed > 0.0,
		"Enabled headwind produces atmospheric wind")
	_assert(windy_sim.telemetry.surface_temperature_k
		> calm_sim.telemetry.surface_temperature_k,
		"Air-relative headwind increases convective heating")
	_dispose_sim(windy_sim)
	_dispose_sim(calm_sim)

	_start_test("Tier 3.3: 1,000 ticks with all Phase 1-12 systems active")
	sim = _instantiate_sim()
	await process_frame
	_configure_sim(sim)
	var director: EncounterDirector = sim.encounter_director
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
		"Phase 12 steady state has zero static growth (%d bytes)" % (
			memory_after - memory_before
		))
	_assert(sim.telemetry.wind_speed >= 0.0, "Wind speed remains non-negative")
	_assert(sim.telemetry.battery_fraction >= 0.0 and sim.telemetry.battery_fraction <= 1.0,
		"Battery fraction remains bounded")
	_assert(director.recorder.count > 0, "Recorder remains active")
	_assert(director.mission.stage != MissionScenarioRunner.STAGE_INACTIVE,
		"Mission remains active")
	_assert(sim.target_pool.active_count <= TargetPoolManager.POOL_SIZE,
		"Target pool remains bounded")
	_dispose_sim(sim)

func _run_tier_4() -> void:
	print("\n--- Tier 4: 38-Script Guardrails and 24-Suite Master Regression Gate ---")
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
		"PlanetaryWindModel.gd", "ShipPowerBusModel.gd", "LandingGearModel.gd",
		"RadarOcclusionModel.gd", "SpaceshipController.gd",
		"EncounterDirector.gd", "SimulationTelemetry.gd", "CockpitHUD.gd"
	]:
		_assert(production_files.has(required), "%s is a production script" % required)
	_assert(_count_lines("res://PlanetarySimulation.gd") <= 248,
		"PlanetarySimulation.gd remains at or below 248 lines")
	_assert(_count_lines("res://ChunkTaskScheduler.gd") <= 248,
		"ChunkTaskScheduler.gd remains at or below 248 lines")
	_assert(_count_lines("res://FlightGuidanceSystem.gd") <= 245,
		"FlightGuidanceSystem.gd remains at or below 245 lines")
	_assert(_count_lines("res://CockpitHUD.gd") <= 249,
		"CockpitHUD.gd remains at or below 249 lines")
	_assert(_count_lines("res://SpaceshipController.gd") <= 220,
		"SpaceshipController.gd remains at or below 220 lines")
	_assert(_count_lines("res://EncounterDirector.gd") <= 245,
		"EncounterDirector.gd remains at or below 245 lines")

	_start_test("Tier 4.2: All 24 prior headless suites pass")
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
		"test_quadtree_headless.gd",
	]
	_assert_int(suites.size(), 24, "Discovered all 24 prior headless suites")
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

func _at_altitude(altitude: float) -> Vector3:
	return Vector3(0.0, PLANET_RADIUS + altitude, 0.0)

func _count_lines(path: String) -> int:
	var text: String = FileAccess.get_file_as_string(path)
	var line_count: int = text.split("\n").size()
	if text.ends_with("\n"):
		line_count -= 1
	return line_count
