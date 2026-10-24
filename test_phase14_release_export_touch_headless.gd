extends SceneTree

## Phase 14 final release verification: export config, touch routing, and 26-suite gate.

const DT: float = 1.0 / 120.0
const REQUIRED_SUITE_COUNT: int = 26
const REQUIRED_PRODUCTION_COUNT: int = 39

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 14 Final Release Verification (Tiers 1-4)")
	print("==================================================================")
	await process_frame
	_run_tier_1()
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

func _assert_vec2(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
	_assert(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [
		message, str(expected), str(actual)
	])

func _print_summary() -> void:
	print("\n==================================================================")
	print("PHASE 14 TEST SUITE EXECUTION SUMMARY")
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
	print("\n--- Tier 1: Project Settings and Android Export Audit ---")
	_start_test("Tier 1.1: Mobile renderer, 120 Hz physics, and landscape display")
	_assert(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile",
		"Rendering method is Mobile")
	_assert_int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 120,
		"Physics ticks run at 120 Hz")
	_assert_int(ProjectSettings.get_setting("display/window/handheld/orientation"), 0,
		"Android orientation is landscape")
	_assert_int(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920,
		"Reference viewport width is 1920")
	_assert_int(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080,
		"Reference viewport height is 1080")
	_assert(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"),
		"Mouse input emulates touch")

	_start_test("Tier 1.2: Android ARM64 preset and documentation")
	var export_path: String = "res://export_presets.cfg"
	_assert(FileAccess.file_exists(export_path), "export_presets.cfg exists")
	var preset: String = FileAccess.get_file_as_string(export_path)
	for expected in [
		'name="Android"', 'platform="Android"', "architectures/arm64-v8a=true",
		"architectures/armeabi-v7a=false", 'package/unique_name="com.cryovanta.protocol"',
		'package/name="Cryovanta Protocol"', 'version/name="1.0.0"',
		"gradle_build/use_gradle_build=false", "xr_features/xr_mode=0",
		'export_path="build/CryovantaProtocol.apk"'
	]:
		_assert(preset.contains(expected), "Android preset contains %s" % expected)
	_assert(FileAccess.file_exists("res://README.md"), "README.md exists")
	var readme: String = FileAccess.get_file_as_string("res://README.md")
	for expected in ["Desktop keyboard", "Android touch", "--export-debug", "Vulkan"]:
		_assert(readme.contains(expected), "README documents %s" % expected)

func _run_tier_2() -> void:
	print("\n--- Tier 2: Multi-Touch Overlay and InputEvent Routing ---")
	_start_test("Tier 2.1: Left-stick translation and upward forward thrust")
	var controller: MobileTouchController = MobileTouchController.new()
	var overlay: MobileTouchOverlay = controller.overlay
	var viewport: Vector2 = Vector2(1920.0, 1080.0)
	_assert(overlay != null, "Controller owns a MobileTouchOverlay")
	overlay.handle_touch_point(true, 3, Vector2(300.0, 700.0), viewport, controller)
	_assert(controller.enabled, "Left touch enables the virtual controller")
	_assert_int(overlay.left_touch_index, 3, "Left touch index is tracked")
	_assert_vec3(controller.thrust_output, Vector3.ZERO, 1e-9,
		"Touch alone does not command thrust")
	overlay.handle_drag_point(3, Vector2(300.0, 610.0), controller)
	_assert(controller.left_stick.y > 0.0,
		"Upward screen drag maps to positive stick Y")
	_assert(controller.thrust_output.z > 0.0,
		"Upward drag produces positive forward thrust")

	_start_test("Tier 2.2: Right-stick pitch/yaw and release reset")
	overlay.handle_touch_point(true, 7, Vector2(1500.0, 700.0), viewport, controller)
	_assert_int(overlay.right_touch_index, 7, "Right touch index is tracked")
	overlay.handle_drag_point(7, Vector2(1590.0, 610.0), controller)
	_assert(controller.torque_output.length() > 0.0, "Right drag produces pitch/yaw torque")
	_assert(controller.thrust_output.z > 0.0,
		"Right-stick input preserves the active left-stick thrust")
	overlay.handle_touch_point(false, 3, Vector2(300.0, 610.0), viewport, controller)
	_assert_int(overlay.left_touch_index, -1, "Left release clears its touch index")
	_assert_vec2(controller.left_stick, Vector2.ZERO, 1e-9, "Left release resets the left stick")
	_assert(controller.torque_output.length() > 0.0, "Left release preserves the right stick")
	overlay.handle_touch_point(false, 7, Vector2(1590.0, 610.0), viewport, controller)
	_assert_int(overlay.right_touch_index, -1, "Right release clears its touch index")
	_assert_vec2(controller.right_stick, Vector2.ZERO, 1e-9, "Right release resets the right stick")
	_assert_vec3(controller.torque_output, Vector3.ZERO, 1e-9,
		"Both releases clear torque output")

	_start_test("Tier 2.3: Top-band fire, mode cycle, and reset semantics")
	overlay.handle_touch_point(true, 11, Vector2(1700.0, 100.0), viewport, controller)
	_assert(overlay.fire_requested, "Top-right tap requests weapon fire")
	_assert_int(overlay.left_touch_index, -1, "Action tap does not claim the left stick")
	_assert_int(overlay.right_touch_index, -1, "Action tap does not claim the right stick")
	overlay.handle_touch_point(true, 12, Vector2(200.0, 100.0), viewport, controller)
	_assert(overlay.cycle_mode_requested, "Top-left tap requests guidance-mode cycling")
	overlay.handle_drag_point(12, Vector2(200.0, 500.0), controller)
	_assert(controller.torque_output.length() == 0.0, "Untracked action touch cannot steer")
	overlay.reset(controller)
	_assert_int(overlay.left_touch_index, -1, "Reset clears the left index")
	_assert_int(overlay.right_touch_index, -1, "Reset clears the right index")
	_assert(not overlay.fire_requested and not overlay.cycle_mode_requested,
		"Reset clears pending action requests")
	_assert_vec3(controller.thrust_output, Vector3.ZERO, 1e-9, "Reset clears thrust output")
	_assert_vec3(controller.torque_output, Vector3.ZERO, 1e-9, "Reset clears torque output")

	_start_test("Tier 2.4: Live _input routing and one-shot action consumption")
	var sim: Node = _instantiate_sim()
	await process_frame
	_configure_sim(sim)
	var live_viewport: Vector2 = get_root().get_visible_rect().size
	var touch_start: Vector2 = Vector2(live_viewport.x * 0.2, live_viewport.y * 0.75)
	var touch_drag: Vector2 = touch_start + Vector2(0.0, -90.0)
	var touch_event: InputEventScreenTouch = InputEventScreenTouch.new()
	touch_event.index = 4
	touch_event.position = touch_start
	touch_event.pressed = true
	sim.weapon_system._input(touch_event)
	var drag_event: InputEventScreenDrag = InputEventScreenDrag.new()
	drag_event.index = 4
	drag_event.position = touch_drag
	sim.weapon_system._input(drag_event)
	_assert_int(sim.touch_controller.overlay.left_touch_index, touch_event.index,
		"Live _input forwards the touch index")
	_assert(sim.touch_controller.thrust_output.z > 0.0,
		"Live _input produces positive forward throttle")
	sim.touch_controller.overlay.cycle_mode_requested = true
	sim.touch_controller.overlay.fire_requested = true
	sim.step_simulation(DT)
	_assert_int(sim.guidance.mode, 1, "Mode tap advances guidance exactly once")
	_assert_int(sim.projectile_pool.active_count, 1, "Fire tap launches one projectile")
	_assert(not sim.touch_controller.overlay.cycle_mode_requested,
		"Mode request is consumed")
	_assert(not sim.touch_controller.overlay.fire_requested, "Fire request is consumed")
	touch_event.pressed = false
	sim.weapon_system._input(touch_event)
	_assert_int(sim.touch_controller.overlay.left_touch_index, -1,
		"Live _input release clears the router index")
	_dispose_sim(sim)

func _run_tier_3() -> void:
	print("\n--- Tier 3: 1,000-Tick Full-Stack Static Memory Gate ---")
	_start_test("Tier 3.1: All Phase 1-14 systems remain allocation-free")
	var sim: Node = _instantiate_sim()
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
	sim.touch_controller.enabled = true
	sim.touch_controller.overlay.handle_touch_point(
		true, 1, Vector2(300.0, 700.0), Vector2(1920.0, 1080.0), sim.touch_controller
	)
	sim.touch_controller.overlay.handle_drag_point(1, Vector2(300.0, 610.0), sim.touch_controller)
	for i in range(120):
		sim.step_simulation(DT)
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		sim.step_simulation(DT)
	var memory_after: int = OS.get_static_memory_usage()
	var memory_delta: int = memory_after - memory_before
	_assert(memory_delta <= 0, "Steady-state static memory delta is <= 0 bytes (%d)" % memory_delta)
	_assert(sim.telemetry.recorded_samples > 0, "Recorder remains active")
	_assert(sim.target_pool.active_count <= TargetPoolManager.POOL_SIZE,
		"Target pool remains bounded")
	_assert(sim.impact_pool.active_count <= ImpactEffectPoolManager.POOL_SIZE,
		"Impact pool remains bounded")
	_assert(sim.projectile_pool.active_count <= ProjectilePoolManager.POOL_SIZE,
		"Projectile pool remains bounded")
	_assert(sim.planet_streamer.get_orphan_mesh_count() == 0, "Streamer has no orphan visuals")
	_assert(sim.touch_controller.overlay.left_touch_index == 1,
		"Overlay touch ownership survives the 1,000-tick run")
	_dispose_sim(sim)

func _run_tier_4() -> void:
	print("\n--- Tier 4: 39-Script Guardrails and 26-Suite Master Regression Gate ---")
	_start_test("Tier 4.1: Every production script declares class_name and stays <= 250 lines")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert_int(production_files.size(), REQUIRED_PRODUCTION_COUNT,
		"Discovered all 39 production scripts")
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = _count_lines("res://" + file)
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
		_assert(line_count > 0 and line_count <= 250,
			"%s has %d lines (limit 250)" % [file, line_count])
	for required in [
		"MobileTouchOverlay.gd", "MobileTouchController.gd", "PlanetarySimulation.gd",
		"EncounterDirector.gd", "PlanetStreamer.gd", "FlightGuidanceSystem.gd"
	]:
		_assert(production_files.has(required), "%s is a production script" % required)
	_assert(_count_lines("res://MobileTouchOverlay.gd") <= 125,
		"MobileTouchOverlay.gd remains at or below 125 lines")
	_assert(_count_lines("res://MobileTouchController.gd") <= 95,
		"MobileTouchController.gd remains at or below 95 lines")
	for frozen in [
		["PlanetarySimulation.gd", 248], ["ChunkTaskScheduler.gd", 248],
		["CockpitHUD.gd", 248], ["FlightGuidanceSystem.gd", 245],
		["PlanetManager.gd", 242], ["PlanetStreamer.gd", 240]
	]:
		_assert(_count_lines("res://" + frozen[0]) <= frozen[1],
			"%s remains at or below %d lines" % [frozen[0], frozen[1]])

	if OS.get_cmdline_user_args().has("--direct-regression"):
		return
	_start_test("Tier 4.2: All 26 prior headless suites pass")
	var suites: Array[String] = _collect_prior_suites()
	_assert_int(suites.size(), REQUIRED_SUITE_COUNT, "Discovered all 26 prior suites")
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

func _collect_prior_suites() -> Array[String]:
	var suites: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.begins_with("test_") and file.ends_with(".gd") \
				and file != "test_phase14_release_export_touch_headless.gd":
			suites.append(file)
	suites.sort()
	return suites

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
