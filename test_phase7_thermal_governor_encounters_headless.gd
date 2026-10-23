extends SceneTree

## Phase 7 headless verification for thermal integrity, frame governance, and encounters.
## Run with: godot --headless -s test_phase7_thermal_governor_encounters_headless.gd

const DT: float = 1.0 / 120.0

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 7 Headless Verification Suite (Tiers 1-5)")
	print("==================================================================")
	await process_frame
	_run_tier_1()
	_run_tier_2()
	await _run_tier_3()
	await _run_tier_4()
	_run_tier_5()
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
	print("PHASE 7 TEST SUITE EXECUTION SUMMARY")
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

func _run_tier_1() -> void:
	print("\n--- Tier 1: Thermal and Structural Integrity ---")
	_start_test("Tier 1.1: Vacuum flight produces no heating and cools to ambient")
	var thermal: ThermalStructuralModel = ThermalStructuralModel.new()
	thermal.surface_temperature_k = 900.0
	thermal.step_thermal(0.25, 0.0, 2000.0, 1.0)
	_assert_approx(thermal.surface_temperature_k, 770.0, 1e-5,
		"Vacuum flight cools toward 250 K")
	_assert_approx(thermal.heat_shield_load, 520.0 / 1150.0, 1e-5,
		"Heat-shield load tracks the cooling surface")
	_assert(not thermal.is_overheating and not thermal.is_over_g,
		"Vacuum cruise is thermally and structurally nominal")

	_start_test("Tier 1.2: Hypersonic entry overheats and ablates the hull")
	thermal.reset()
	thermal.step_thermal(DT, 0.6, 1800.0, 2.0)
	_assert(thermal.surface_temperature_k > 1400.0,
		"Hypersonic stagnation heating exceeds the safe temperature")
	_assert(thermal.is_overheating, "Overheat flag latches")
	_assert(thermal.heat_shield_load > 1.0, "Heat-shield load exceeds nominal")
	_assert(thermal.hull_integrity < thermal.max_hull_integrity,
		"Overheat load ablates hull integrity")

	_start_test("Tier 1.3: Excessive G-load damages the structure")
	thermal.reset()
	thermal.step_thermal(DT, 0.0, 0.0, 18.0)
	_assert(thermal.is_over_g, "Over-G flag latches above 12 G")
	_assert(thermal.hull_integrity < thermal.max_hull_integrity,
		"Over-G load reduces hull integrity")
	_assert(thermal.hull_integrity >= 0.0, "Hull integrity remains bounded")
	thermal.reset()
	_assert_approx(thermal.hull_integrity, 100.0, 0.0, "Reset restores full hull")
	_assert_approx(thermal.surface_temperature_k, 250.0, 0.0,
		"Reset restores ambient temperature")

func _run_tier_2() -> void:
	print("\n--- Tier 2: Adaptive 120 FPS Frame-Budget Governor ---")
	_start_test("Tier 2.1: Sustained heavy frames reduce quadtree split scale")
	var manager: PlanetManager = PlanetManager.new()
	var governor: FrameBudgetGovernor = FrameBudgetGovernor.new()
	governor.reset(manager.lod_split_scale)
	for i in range(20):
		governor.sample_frame_time(14.0, manager)
	_assert(governor.over_budget_streak > 0, "Over-budget streak increments")
	_assert(governor.recommended_split_scale < 2.0,
		"Heavy frames lower the recommended split scale")
	_assert_approx(manager.lod_split_scale, governor.recommended_split_scale, 1e-6,
		"PlanetManager receives the adaptive split scale")
	var close_camera: Vector3 = Vector3(100_000.0, 0.0, 0.0)
	for i in range(12):
		manager.update_camera(close_camera)
	var reduced_leaves: int = manager.get_all_leaves().size()

	_start_test("Tier 2.2: Sustained fast frames recover quadtree detail")
	var reduced_scale: float = governor.recommended_split_scale
	for i in range(30):
		governor.sample_frame_time(4.5, manager)
	_assert(governor.under_budget_streak > 0, "Under-budget streak increments")
	_assert(governor.recommended_split_scale > reduced_scale,
		"Fast frames recover split scale")
	_assert(manager.lod_split_scale <= FrameBudgetGovernor.MAX_SPLIT_SCALE,
		"Split scale stays within the upper bound")
	for i in range(12):
		manager.update_camera(close_camera)
	_assert(manager.get_all_leaves().size() >= reduced_leaves,
		"Recovered split scale restores quadtree detail")

	_start_test("Tier 2.3: Nominal 120 Hz frames keep quadtree detail steady")
	governor.reset(manager.lod_split_scale)
	var initial_scale: float = manager.lod_split_scale
	for i in range(240):
		governor.sample_frame_time(1000.0 * DT, manager)
	var steady_scale: float = manager.lod_split_scale
	for i in range(12):
		manager.update_camera(close_camera)
	var steady_leaves: int = manager.get_all_leaves().size()
	governor.reset(steady_scale)
	for i in range(240):
		governor.sample_frame_time(1000.0 * DT, manager)
	for i in range(12):
		manager.update_camera(close_camera)
	_assert_approx(manager.lod_split_scale, initial_scale, 1e-6,
		"Nominal 8.333 ms frames do not perturb LOD")
	_assert_int(manager.get_all_leaves().size(), steady_leaves,
		"Nominal frames preserve the settled quadtree topology")
	_assert_int(governor.over_budget_streak, 0, "Nominal frames clear over-budget streak")
	_assert_int(governor.under_budget_streak, 0, "Nominal frames clear under-budget streak")

	_start_test("Tier 2.4: Governor clamps to its documented bounds")
	governor.reset(-10.0)
	_assert_approx(governor.recommended_split_scale, 1.0, 0.0,
		"Reset clamps below the minimum")
	governor.reset(99.0)
	_assert_approx(governor.recommended_split_scale, 4.0, 0.0,
		"Reset clamps above the maximum")
	governor.enabled = false
	var frozen_scale: float = governor.recommended_split_scale
	for i in range(30):
		governor.sample_frame_time(100.0, manager)
	_assert_approx(governor.recommended_split_scale, frozen_scale, 0.0,
		"Disabled governor leaves the split scale unchanged")
	manager.destroy()
	manager.free()

func _run_tier_3() -> void:
	print("\n--- Tier 3: Orbital Encounter Director and Wave Spawning ---")
	_start_test("Tier 3.1: Drone ring spawns tangent to the local radial-up")
	var targets: TargetPoolManager = TargetPoolManager.new()
	get_root().add_child(targets)
	var director: EncounterDirector = EncounterDirector.new()
	var center: Vector3 = Vector3.ZERO
	var ship_pos: Vector3 = Vector3(0.0, 100_350.0, 0.0)
	var spawned: int = director.spawn_drone_ring(ship_pos, center, targets, 4)
	_assert_int(spawned, 4, "Ring spawner fills the requested wave")
	_assert_int(targets.active_count, 4, "Target pool reports the active wave")
	_assert_int(director.wave_counter, 1, "Spawner increments the wave counter")
	var radial_up: Vector3 = (ship_pos - center).normalized()
	var spawn_ids: Array[int] = []
	for id in range(TargetPoolManager.POOL_SIZE):
		if not targets.is_in_use[id]:
			continue
		spawn_ids.append(id)
		var offset: Vector3 = targets.get_target_position(id) - ship_pos
		_assert_approx(offset.dot(radial_up), 0.0, 1e-4,
			"Target %d lies in the local orbital plane" % id)
		_assert_approx(offset.length(), director.spawn_radius, 1e-4,
			"Target %d uses the configured spawn radius" % id)
		var velocity: Vector3 = targets.get_target_velocity(id)
		_assert_approx(velocity.length(), director.target_orbital_speed, 1e-4,
			"Target %d uses the configured orbital speed" % id)
		_assert_approx(velocity.dot(radial_up), 0.0, 1e-4,
			"Target %d velocity is tangential" % id)
		_assert_int(targets.bodies[id].collision_layer, 4,
			"Target %d remains on collision layer 4" % id)
		_assert_approx(targets.health[id], 100.0, 0.0, "Target starts at full health")
	var first_position: Vector3 = targets.get_target_position(spawn_ids[0])
	director.wave_counter = 0
	targets.clear()
	director.spawn_drone_ring(ship_pos, center, targets, 4)
	_assert_vec3(targets.get_target_position(spawn_ids[0]), first_position, 1e-6,
		"Deterministic ring placement repeats for the same wave")
	var all_ids: Array[int] = []
	var id_cursor: int = 0
	while id_cursor < TargetPoolManager.POOL_SIZE:
		if targets.is_in_use[id_cursor]:
			all_ids.append(id_cursor)
		id_cursor += 1
	_assert_int(all_ids.size(), 4, "Deterministic spawn remains allocation-bounded")
	director.spawn_drone_ring(ship_pos, center, targets, 32)
	_assert_int(targets.active_count, TargetPoolManager.POOL_SIZE,
		"Ring spawner fills the fixed target pool without overflow")
	_assert_int(director.spawn_drone_ring(ship_pos, center, targets, 1), 0,
		"Exhausted target pool spawns no extra targets")

	_start_test("Tier 3.2: Auto-spawn creates and replaces encounter waves")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.encounter_director.desired_active_targets = 4
	sim.encounter_director.auto_spawn_waves = true
	sim.step_simulation(DT)
	_assert_int(sim.target_pool.active_count, 4, "First wave auto-spawns")
	_assert_int(sim.encounter_director.wave_counter, 1, "First wave is recorded")
	_assert(sim.weapon_system.locked_target_id >= 0,
		"Auto-spawn acquires the nearest target")
	for id in range(TargetPoolManager.POOL_SIZE):
		if sim.target_pool.is_in_use[id]:
			sim.target_pool.apply_damage(id, 1.0e9)
	_assert_int(sim.target_pool.active_count, 0, "Wave one is fully destroyed")
	sim.step_simulation(DT)
	_assert_int(sim.target_pool.active_count, 4, "Second wave auto-spawns")
	_assert_int(sim.encounter_director.wave_counter, 2, "Second wave is recorded")
	_assert(sim.weapon_system.locked_target_id >= 0,
		"Second wave acquires a target lock")
	sim.encounter_director.auto_spawn_waves = false
	sim.target_pool.clear()
	sim.step_simulation(DT)
	_assert_int(sim.target_pool.active_count, 0,
		"Default-disabled auto-spawn leaves the pool empty")
	_assert_int(sim.encounter_director.wave_counter, 2,
		"Disabled auto-spawn does not advance the wave counter")
	_dispose_sim(sim)
	get_root().remove_child(targets)
	targets.free()

func _run_tier_4() -> void:
	print("\n--- Tier 4: Simulation Integration, HUD Sync, and Memory ---")
	_start_test("Tier 4.1: Thermal, hull, and governor telemetry reaches HUD")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.ship.global_position = Vector3.ZERO
	sim.ship.linear_velocity = Vector3(0.0, -1800.0, 0.0)
	sim.encounter_director.target_initial_health = 1.0e9
	sim.encounter_director.auto_spawn_waves = true
	sim.step_simulation(DT)
	var telemetry: SimulationTelemetry = sim.telemetry
	var director: EncounterDirector = sim.encounter_director
	_assert_approx(telemetry.surface_temperature_k, director.thermal.surface_temperature_k, 1e-6,
		"Telemetry mirrors surface temperature")
	_assert_approx(telemetry.heat_shield_load, director.thermal.heat_shield_load, 1e-6,
		"Telemetry mirrors heat-shield load")
	_assert_approx(telemetry.hull_integrity, director.thermal.hull_integrity, 1e-6,
		"Telemetry mirrors hull integrity")
	_assert_approx(telemetry.ema_frame_ms, director.governor.ema_frame_ms, 1e-6,
		"Telemetry mirrors governor EMA")
	_assert_approx(telemetry.governor_split_scale, director.governor.recommended_split_scale,
		1e-6, "Telemetry mirrors governor split scale")
	_assert_approx(sim.hud.displayed_heat_load, telemetry.heat_shield_load, 1e-9,
		"HUD mirrors heat-shield load")
	_assert_approx(sim.hud.displayed_hull_integrity, telemetry.hull_integrity, 1e-9,
		"HUD mirrors hull integrity")
	_assert_int(sim.hud.last_drawn_thermal_bars, 2,
		"HUD draws both compact hull and thermal bars")
	_assert_approx(sim.planet_manager.lod_split_scale,
		director.governor.recommended_split_scale, 1e-6,
		"Governor owns the live PlanetManager split scale")

	_start_test("Tier 4.2: 1,000 active encounter ticks have zero static growth")
	for i in range(120):
		sim.step_simulation(DT)
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		sim.step_simulation(DT)
	var memory_after: int = OS.get_static_memory_usage()
	_assert(memory_after - memory_before <= 0,
		"Phase 7 steady state has zero static growth (%d bytes)" % (
			memory_after - memory_before
		))
	_assert_int(sim.target_pool.active_count, 4, "Encounter wave remains active")
	_assert_int(sim.target_pool.bodies.size(), TargetPoolManager.POOL_SIZE,
		"Target pool remains fixed-size")
	_assert(sim.encounter_director.thermal.hull_integrity >= 0.0,
		"Thermal integrity remains bounded")
	_dispose_sim(sim)

func _run_tier_5() -> void:
	print("\n--- Tier 5: 28-Script Guardrails and 19-Suite Regression Gate ---")
	_start_test("Tier 5.1: All 28 production scripts declare class_name and stay <= 250 lines")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert(production_files.size() >= 28, "Discovered all 28 production scripts")
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = text.split("\n").size()
		if text.ends_with("\n"):
			line_count -= 1
		_assert(line_count > 0 and line_count <= 250,
			"%s has %d lines (limit 250)" % [file, line_count])
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
	for required in [
		"ThermalStructuralModel.gd", "FrameBudgetGovernor.gd", "EncounterDirector.gd",
		"PlanetarySimulation.gd", "SimulationTelemetry.gd", "CockpitHUD.gd"
	]:
		_assert(production_files.has(required), "%s is a production script" % required)
	_assert(_count_lines("res://PlanetarySimulation.gd") <= 250,
		"PlanetarySimulation.gd remains within its 250-line ceiling")

	if OS.get_cmdline_user_args().has("--direct-regression"):
		print("  [SKIP] Nested Phase 1-6 regression gate (direct Phase 9 orchestration)")
		return
	_start_test("Tier 5.2: All 19 prior Phase 1-6 suites pass")
	var suites: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.begins_with("test_") and file.ends_with(".gd") \
			and file != "test_phase7_thermal_governor_encounters_headless.gd" \
			and file != "test_phase8_waypoints_evasion_hud_headless.gd":
			suites.append(file)
	suites.sort()
	_assert_int(suites.size(), 19, "Discovered all 19 prior headless suites")
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

func _count_lines(path: String) -> int:
	var text: String = FileAccess.get_file_as_string(path)
	var line_count: int = text.split("\n").size()
	if text.ends_with("\n"):
		line_count -= 1
	return line_count
