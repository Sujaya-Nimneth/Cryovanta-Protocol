extends SceneTree

## Phase 8 headless verification for waypoints, evasion, and HUD projection.
## Run with: godot --headless -s test_phase8_waypoints_evasion_hud_headless.gd

const DT: float = 1.0 / 120.0
const PHASE8_SUITE: String = "test_phase8_waypoints_evasion_hud_headless.gd"

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 8 Headless Verification Suite (Tiers 1-5)")
	print("==================================================================")
	await process_frame
	_run_tier_1()
	_run_tier_2()
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
	print("PHASE 8 TEST SUITE EXECUTION SUMMARY")
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
	print("\n--- Tier 1: 16-Slot Waypoint and Surface Beacon Ring Buffer ---")
	_start_test("Tier 1.1: Fixed capacity, clear, and deterministic first-free acquisition")
	var ring: WaypointRingBuffer = WaypointRingBuffer.new()
	_assert_int(ring.MAX_WAYPOINTS, 16, "Waypoint capacity is 16")
	_assert_int(ring.positions.size(), 16, "Positions are preallocated")
	_assert_int(ring.radii.size(), 16, "Radii are preallocated")
	_assert_int(ring.is_active.size(), 16, "Active flags are preallocated")
	for i in range(16):
		_assert_int(ring.add_waypoint(Vector3(float(i), 0.0, 0.0), 10.0), i,
			"Waypoint %d acquires the first free slot" % i)
	_assert_int(ring.active_count, 16, "All 16 slots are active")
	_assert_int(ring.add_waypoint(Vector3.ZERO), -1, "17th waypoint is rejected")
	_assert_int(ring.current_waypoint_id, 0, "First added waypoint becomes current")
	ring.clear()
	_assert_int(ring.active_count, 0, "Clear resets active count")
	_assert_int(ring.current_waypoint_id, -1, "Clear resets current waypoint")
	_assert_int(ring.completed_waypoints, 0, "Clear resets completion count")
	_assert_approx(ring.distance_to_current, 0.0, 0.0, "Clear resets distance")
	_assert_vec3(ring.positions[0], Vector3.ZERO, 0.0, "Clear resets position")
	_assert_approx(ring.radii[0], 150.0, 0.0, "Clear restores default radius")

	_start_test("Tier 1.2: Surface beacons use exact terrain radial height")
	var unit_dir: Vector3 = Vector3(1.0, 2.0, -3.0).normalized()
	var center: Vector3 = Vector3(0.0, -100_000.0, 0.0)
	var planet_radius: float = 100_000.0
	var altitude: float = 50.0
	var beacon_id: int = ring.add_surface_beacon(unit_dir, center, planet_radius, altitude, 42.0)
	var expected_dist: float = PlanetMath.get_terrain_height(unit_dir, planet_radius) + altitude
	_assert_int(beacon_id, 0, "Surface beacon acquires a slot")
	_assert_approx(ring.positions[beacon_id].distance_to(center), expected_dist, 0.01,
		"Beacon uses terrain height plus altitude")
	_assert_approx(ring.radii[beacon_id], 42.0, 0.0, "Beacon stores its capture radius")
	_assert_vec3(ring.positions[beacon_id], center + unit_dir * expected_dist, 0.05,
		"Beacon lies on its surface radial")

	_start_test("Tier 1.3: Sequential capture, advancement, and 2,000 m rebase")
	ring.clear()
	ring.add_waypoint(Vector3(100.0, 0.0, 0.0), 25.0)
	ring.add_waypoint(Vector3(300.0, 0.0, 0.0), 25.0)
	_assert(not ring.step_waypoints(Vector3.ZERO), "Distant waypoint is not captured")
	_assert_approx(ring.distance_to_current, 100.0, 1e-6, "Distance tracks current waypoint")
	_assert(ring.step_waypoints(Vector3(100.0, 0.0, 0.0)), "Current waypoint is captured")
	_assert_int(ring.completed_waypoints, 1, "Capture increments completion count")
	_assert_int(ring.current_waypoint_id, 1, "Capture advances to the next active slot")
	_assert_approx(ring.distance_to_current, 200.0, 1e-6,
		"Capture updates distance to the advanced waypoint")
	var offset: Vector3 = Vector3(2_000.0, -250.0, 400.0)
	var before: Vector3 = ring.get_current_waypoint_position()
	ring.rebase_origin(offset)
	_assert_vec3(ring.get_current_waypoint_position(), before - offset, 1e-6,
		"Waypoint shifts by -offset")
	_assert(ring.step_waypoints(before - offset), "Rebased waypoint is captured")
	_assert_int(ring.active_count, 0, "Capturing the final waypoint empties the ring")
	_assert_int(ring.current_waypoint_id, -1, "Empty ring has no current waypoint")
	_assert_vec3(ring.get_current_waypoint_position(), Vector3.ZERO, 0.0,
		"Empty ring reports the zero position")
	_assert(not ring.step_waypoints(Vector3.ZERO), "Empty ring cannot capture")

func _run_tier_2() -> void:
	print("\n--- Tier 2: Deterministic Evasive Drone Steering ---")
	_start_test("Tier 2.1: Disabled evasion leaves target velocities unchanged")
	var targets: TargetPoolManager = TargetPoolManager.new()
	get_root().add_child(targets)
	var director: EncounterDirector = EncounterDirector.new()
	var center: Vector3 = Vector3.ZERO
	var ship_pos: Vector3 = Vector3(0.0, 100_000.0, 0.0)
	var first_id: int = targets.spawn_target(
		ship_pos + Vector3(300.0, 0.0, 0.0), Vector3(0.0, 0.0, 45.0), 100.0
	)
	var second_id: int = targets.spawn_target(
		ship_pos + Vector3(0.0, 0.0, 300.0), Vector3(45.0, 0.0, 0.0), 100.0
	)
	var first_before: Vector3 = targets.get_target_velocity(first_id)
	var second_before: Vector3 = targets.get_target_velocity(second_id)
	_assert(not director.evasion_enabled, "Evasion defaults to disabled")
	for i in range(64):
		director.step_evasion(DT, ship_pos, center, targets)
	_assert_vec3(targets.get_target_velocity(first_id), first_before, 0.0,
		"Disabled evasion preserves first velocity")
	_assert_vec3(targets.get_target_velocity(second_id), second_before, 0.0,
		"Disabled evasion preserves second velocity")

	_start_test("Tier 2.2: Enabled evasion is deterministic, orthogonal, and speed-bounded")
	director.evasion_enabled = true
	director.elapsed_time = 0.0
	director.step_evasion(DT, ship_pos, center, targets)
	var first_weave: Vector3 = targets.get_target_velocity(first_id)
	var second_weave: Vector3 = targets.get_target_velocity(second_id)
	_assert(first_weave.distance_to(first_before) > 1e-6, "First drone receives a weave")
	_assert(second_weave.distance_to(second_before) > 1e-6, "Second drone receives a weave")
	_assert_approx(first_weave.length(), director.target_orbital_speed, 1e-5,
		"First drone speed remains bounded")
	_assert_approx(second_weave.length(), director.target_orbital_speed, 1e-5,
		"Second drone speed remains bounded")
	var radial_up: Vector3 = (ship_pos - center).normalized()
	var first_delta: Vector3 = first_weave - first_before
	_assert(absf(first_delta.dot(radial_up)) > 1e-6,
		"Weave includes a radial component")
	_assert(absf(first_delta.dot(first_before.normalized())) > 1e-6,
		"Weave introduces a lateral component")
	targets.velocities[first_id] = first_before
	targets.velocities[second_id] = second_before
	director.elapsed_time = 0.0
	director.step_evasion(DT, ship_pos, center, targets)
	_assert_vec3(targets.get_target_velocity(first_id), first_weave, 1e-6,
		"Replaying the same time produces the same first velocity")
	_assert_vec3(targets.get_target_velocity(second_id), second_weave, 1e-6,
		"Replaying the same time produces the same second velocity")
	director.elapsed_time = 0.0
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		director.step_evasion(DT, ship_pos, center, targets)
	var memory_after: int = OS.get_static_memory_usage()
	_assert(memory_after - memory_before <= 0,
		"1,000 evasion ticks have zero static growth (%d bytes)" % (
			memory_after - memory_before
		))
	_assert_approx(targets.get_target_velocity(first_id).length(),
		director.target_orbital_speed, 1e-5, "Sustained weaving preserves first speed")
	_assert_approx(targets.get_target_velocity(second_id).length(),
		director.target_orbital_speed, 1e-5, "Sustained weaving preserves second speed")
	get_root().remove_child(targets)
	targets.free()

func _run_tier_3() -> void:
	print("\n--- Tier 3: Live Waypoint Capture, Rebase, and HUD Diamond ---")
	_start_test("Tier 3.1: Live telemetry and in-tree HUD diamond projection")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.global_position = Vector3.ZERO
	sim.ship.linear_velocity = Vector3.ZERO
	sim.ship.angular_velocity = Vector3.ZERO
	var camera: Camera3D = sim.camera
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	sim.encounter_director.waypoints.clear()
	var first_id: int = sim.encounter_director.waypoints.add_waypoint(
		camera.global_position + forward * 250.0, 30.0
	)
	var second_id: int = sim.encounter_director.waypoints.add_waypoint(
		camera.global_position + forward * 500.0, 30.0
	)
	_assert_int(first_id, 0, "First live waypoint occupies slot 0")
	_assert_int(second_id, 1, "Second live waypoint occupies slot 1")
	sim.step_simulation(DT)
	_assert_int(sim.telemetry.active_waypoints, 2, "Telemetry reports two active waypoints")
	_assert_int(sim.hud.active_waypoint_id, 0, "HUD tracks the first waypoint")
	_assert_vec3(sim.hud.active_waypoint_pos,
		sim.encounter_director.waypoints.get_current_waypoint_position(), 1e-5,
		"HUD position mirrors the ring buffer")
	_assert_approx(sim.hud.displayed_waypoint_distance, sim.telemetry.waypoint_distance, 1e-9,
		"HUD distance mirrors telemetry")
	_assert(not camera.is_position_behind(sim.hud.active_waypoint_pos),
		"Live waypoint is in front of the camera")
	sim.hud._surface.queue_redraw()
	await process_frame
	await process_frame
	_assert_int(sim.hud.last_drawn_waypoint_markers, 1,
		"HUD draws one waypoint diamond")

	_start_test("Tier 3.2: Floating-origin rebase shifts waypoints and HUD together")
	var offset: Vector3 = Vector3(2_000.0, -250.0, 400.0)
	var ring_before: Vector3 = sim.encounter_director.waypoints.get_current_waypoint_position()
	var hud_before: Vector3 = sim.hud.active_waypoint_pos
	sim.floating_origin.rebase(offset)
	_assert_vec3(sim.encounter_director.waypoints.get_current_waypoint_position(),
		ring_before - offset, 1e-5, "Director waypoint shifts by -offset")
	_assert_vec3(sim.hud.active_waypoint_pos, hud_before - offset, 1e-5,
		"HUD waypoint shifts by -offset")

	_start_test("Tier 3.3: Entering capture radius completes and advances the waypoint")
	var current_id: int = sim.encounter_director.waypoints.current_waypoint_id
	var target_pos: Vector3 = sim.encounter_director.waypoints.positions[current_id]
	sim.ship.global_position = target_pos
	sim.floating_origin.player_node = null
	sim.step_simulation(DT)
	_assert_int(sim.telemetry.completed_waypoints, 1, "First waypoint is completed")
	_assert_int(sim.telemetry.active_waypoints, 1, "One waypoint remains active")
	_assert_int(sim.hud.active_waypoint_id, 1, "HUD advances to the second waypoint")
	_assert(sim.ship.global_position.distance_to(target_pos) <= 1.0,
		"Ship remains inside the capture radius during the tick")
	_dispose_sim(sim)

func _run_tier_4() -> void:
	print("\n--- Tier 4: 1,000-Tick Steady-State Zero Static Growth ---")
	_start_test("Tier 4.1: Active waypoints, auto-spawn, and evasion stay allocation-free")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.global_position = Vector3.ZERO
	sim.ship.linear_velocity = Vector3.ZERO
	sim.encounter_director.auto_spawn_waves = true
	sim.encounter_director.desired_active_targets = 4
	sim.encounter_director.evasion_enabled = true
	sim.encounter_director.target_initial_health = 1.0e9
	var forward: Vector3 = -sim.camera.global_transform.basis.z.normalized()
	for i in range(4):
		sim.encounter_director.waypoints.add_waypoint(
			sim.ship.global_position + forward * (2_500.0 + 1_000.0 * float(i)),
			40.0
		)
	for i in range(120):
		sim.step_simulation(DT)
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		sim.step_simulation(DT)
	var memory_after: int = OS.get_static_memory_usage()
	_assert(memory_after - memory_before <= 0,
		"Phase 8 steady state has zero static growth (%d bytes)" % (
			memory_after - memory_before
		))
	_assert_int(sim.target_pool.active_count, 4, "Auto-spawn keeps the wave active")
	_assert_int(sim.encounter_director.waypoints.active_count, 4,
		"Waypoints remain active throughout the run")
	_assert(sim.encounter_director.elapsed_time > 0.0, "Evasion clock advances")
	_dispose_sim(sim)

func _run_tier_5() -> void:
	print("\n--- Tier 5: 29-Script Guardrails and 20-Suite Regression Gate ---")
	_start_test("Tier 5.1: All 29 production scripts declare class_name and stay <= 250 lines")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert(production_files.size() >= 29,
		"Discovered all 29 Phase 8 production scripts (found %d)" % production_files.size())
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = _count_lines("res://" + file)
		_assert(line_count > 0 and line_count <= 250,
			"%s has %d lines (limit 250)" % [file, line_count])
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
	for required in [
		"WaypointRingBuffer.gd", "EncounterDirector.gd", "PlanetarySimulation.gd",
		"SimulationTelemetry.gd", "CockpitHUD.gd", "ChunkTaskScheduler.gd"
	]:
		_assert(production_files.has(required), "%s is a production script" % required)
	_assert(_count_lines("res://PlanetarySimulation.gd") <= 250,
		"PlanetarySimulation.gd remains within its 250-line ceiling")
	_assert(_count_lines("res://ChunkTaskScheduler.gd") <= 250,
		"ChunkTaskScheduler.gd remains within its 250-line ceiling")

	if OS.get_cmdline_user_args().has("--direct-regression"):
		print("  [SKIP] Nested Phase 1-7 regression gate (direct Phase 9 orchestration)")
		return
	_start_test("Tier 5.2: All 20 prior Phase 1-7 suites pass")
	var suites: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.begins_with("test_") and file.ends_with(".gd") and file != PHASE8_SUITE:
			suites.append(file)
	suites.sort()
	_assert_int(suites.size(), 20, "Discovered all 20 prior headless suites")
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
