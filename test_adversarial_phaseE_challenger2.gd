extends SceneTree

## Empirical Challenger 2 Stress Test Suite for Phase E
## Validates:
## 1. Live sortie bootstrap (auto_step = true) & backward compatibility
## 2. Multi-touch release & keyboard flight controls coexistence
## 3. Flight rewind KEY_R and angular velocity zeroing
## 4. 1,000-tick static heap memory delta (delta <= 0)
## 5. Terrain cube-face seam continuity
## 6. 42-script architectural line ceilings and class_name invariants

const DT: float = 1.0 / 120.0
const PLANET_RADIUS: float = 100_000.0

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_stress_suite.call_deferred()

func _run_stress_suite() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase E Empirical Challenger Stress Suite")
	print("==================================================================")
	await process_frame
	await _test_live_sortie_bootstrap()
	await _test_touch_release_coexistence()
	await _test_flight_rewind_angular_zeroing()
	await _test_thousand_tick_static_memory()
	_test_seam_continuity_probe()
	_test_production_script_architecture()
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
	_assert(absf(actual - expected) <= tolerance, "%s (expected %.6f, got %.6f)" % [
		message, expected, actual
	])

func _assert_vec3(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> void:
	_assert(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [
		message, str(expected), str(actual)
	])

func _print_summary() -> void:
	print("==================================================================")
	print("CHALLENGER STRESS SUITE SUMMARY")
	print("==================================================================")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	print("==================================================================")
	if failed_assertions == 0:
		print("SUCCESS: Empirical challenger verified all Phase E criteria!")
	else:
		printerr("FAILURE: %d assertions failed!" % failed_assertions)

# -----------------------------------------------------------------------------
# 1. Live Sortie Bootstrap & Invariance
# -----------------------------------------------------------------------------
func _test_live_sortie_bootstrap() -> void:
	print("\n--- Suite 1: Live Sortie Bootstrap & Invariance ---")
	_start_test("Suite 1.1: Live auto_step = true bootstrap from main.tscn")
	var packed: PackedScene = load("res://main.tscn")
	_assert(packed != null, "main.tscn loads successfully")
	var sim: PlanetarySimulation = packed.instantiate()
	_assert(sim != null, "main.tscn instantiates as PlanetarySimulation")
	sim.auto_step = true
	get_root().add_child(sim)
	await process_frame
	await process_frame

	_assert(sim.ship.process_user_input == true, "Live sortie activates ship.process_user_input")
	_assert_approx(sim.ship.mass, 1600.0, 1.0, "Ship mass matches propellant wet mass (1600 kg)")
	_assert_vec3(sim.ship.inertia, Vector3(2000.0, 2000.0, 3000.0), 0.1, "Ship inertia matches baseline")
	_assert(sim.ship.visual_rig != null, "Ship visual rig attached")

	var dir: EncounterDirector = sim.encounter_director
	_assert(dir != null, "EncounterDirector valid")
	_assert(dir.mission.stage != MissionScenarioRunner.STAGE_INACTIVE, "Sortie mission is active")
	_assert_int(dir.mission.stage, MissionScenarioRunner.STAGE_WAYPOINT_RECON,
		"Sortie starts in STAGE_WAYPOINT_RECON")
	_assert(dir.landing_gear.enabled, "Landing gear enabled")
	_assert(not dir.landing_gear.deployed, "Landing gear initially retracted for flight")
	_assert(dir.propellant.enabled, "Propellant enabled")
	_assert(dir.wind.enabled, "Wind model enabled")
	_assert(dir.power_bus.enabled, "Power bus enabled")
	_assert(dir.recorder.recording_enabled, "Flight recorder enabled")
	_assert(dir.evasion_enabled, "Drone evasion enabled")
	_assert(dir.auto_spawn_waves, "Wave spawner enabled")
	_assert(sim.weapon_system.capacitor.enabled, "Weapon capacitor enabled")
	_assert(sim.planet_streamer.mesh_loaded.size() > 0, "Initial coarse chunks bootstrapped")

	# Step 60 frames in live sortie mode
	for i in range(60):
		sim.step_simulation(DT)
	_assert(dir.propellant.propellant_mass <= 600.0, "Propellant mass tracked over live flight")
	_assert(dir.recorder.count > 0, "Flight recorder recorded live snapshots")

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

	_start_test("Suite 1.2: auto_step = false backward compatibility invariance")
	var sim_inert: PlanetarySimulation = packed.instantiate()
	sim_inert.auto_step = false
	get_root().add_child(sim_inert)
	await process_frame
	_assert(sim_inert.ship.process_user_input == false, "Inactive sortie leaves input off")
	_assert_int(sim_inert.encounter_director.mission.stage, MissionScenarioRunner.STAGE_INACTIVE,
		"Inactive sortie leaves mission in STAGE_INACTIVE")
	sim_inert.destroy()
	get_root().remove_child(sim_inert)
	sim_inert.free()

# -----------------------------------------------------------------------------
# 2. Multi-Touch Release & Keyboard Coexistence
# -----------------------------------------------------------------------------
func _test_touch_release_coexistence() -> void:
	print("\n--- Suite 2: Multi-Touch Release & Keyboard Coexistence ---")
	_start_test("Suite 2.1: Interleaved dual-touch press and out-of-order release")
	var controller: MobileTouchController = MobileTouchController.new()
	var overlay: MobileTouchOverlay = controller.overlay
	var viewport: Vector2 = Vector2(1920.0, 1080.0)

	# Left touch on stick
	overlay.handle_touch_point(true, 10, Vector2(300.0, 700.0), viewport, controller)
	_assert(controller.enabled, "Controller enabled with touch index 10")
	_assert_int(overlay.left_touch_index, 10, "Left index tracked")

	# Right touch on stick
	overlay.handle_touch_point(true, 20, Vector2(1600.0, 700.0), viewport, controller)
	_assert(controller.enabled, "Controller remains enabled with touch index 20")
	_assert_int(overlay.right_touch_index, 20, "Right index tracked")

	# Drag left stick
	overlay.handle_drag_point(10, Vector2(300.0, 610.0), controller)
	_assert(controller.thrust_output.z > 0.5, "Forward thrust produced from left drag")

	# Drag right stick
	overlay.handle_drag_point(20, Vector2(1690.0, 700.0), controller)
	_assert(controller.torque_output.y > 0.5, "Yaw torque produced from right drag")

	# Release left touch FIRST: right touch is still held!
	overlay.handle_touch_point(false, 10, Vector2(300.0, 610.0), viewport, controller)
	_assert_int(overlay.left_touch_index, -1, "Left index released")
	_assert_int(overlay.right_touch_index, 20, "Right index still held")
	_assert(controller.enabled, "Controller remains enabled while right stick is held")
	_assert_vec3(controller.thrust_output, Vector3.ZERO, 1e-6, "Left thrust zeroed on release")
	_assert(controller.torque_output.y > 0.5, "Right torque preserved while right stick held")

	# Release right touch: both are now -1
	overlay.handle_touch_point(false, 20, Vector2(1690.0, 700.0), viewport, controller)
	_assert_int(overlay.left_touch_index, -1, "Left index is -1")
	_assert_int(overlay.right_touch_index, -1, "Right index is -1")
	_assert(not controller.enabled, "controller.enabled drops to false when both fingers release!")

	_start_test("Suite 2.2: Untracked touch index release does not disrupt active touches")
	overlay.handle_touch_point(true, 5, Vector2(300.0, 700.0), viewport, controller)
	_assert_int(overlay.left_touch_index, 5, "Touch 5 registered")
	# Untracked touch release event
	overlay.handle_touch_point(false, 99, Vector2(500.0, 500.0), viewport, controller)
	_assert_int(overlay.left_touch_index, 5, "Left index preserved after untracked release")
	_assert(controller.enabled, "Controller remains enabled")
	overlay.handle_touch_point(false, 5, Vector2(300.0, 700.0), viewport, controller)
	_assert(not controller.enabled, "Controller disabled after tracked release")

	_start_test("Suite 2.3: Keyboard controls active when touch_controller.enabled == false")
	var sim: PlanetarySimulation = PlanetarySimulation.new()
	sim.auto_step = false
	sim.setup_simulation(true)
	get_root().add_child(sim)
	await process_frame
	sim.ship.process_user_input = true
	sim.touch_controller.enabled = false

	# Set manual keyboard thrust input on ship
	sim.ship.set_thrust_input(Vector3(0.0, 0.0, 1.0))
	sim.ship.set_torque_input(Vector3(0.5, 0.0, 0.0))
	_assert_vec3(sim.ship.thrust_input, Vector3(0.0, 0.0, 1.0), 1e-6, "Ship holds thrust input")
	_assert_vec3(sim.ship.torque_input, Vector3(0.5, 0.0, 0.0), 1e-6, "Ship holds torque input")

	# Step simulation
	sim.step_simulation(DT)
	# Verify thrust force was applied
	_assert(sim.ship.get_current_net_force().length() > 0.0, "Thrust applied to ship")

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

# -----------------------------------------------------------------------------
# 3. Flight Rewind KEY_R & Angular Velocity Zeroing
# -----------------------------------------------------------------------------
func _test_flight_rewind_angular_zeroing() -> void:
	print("\n--- Suite 3: Flight Rewind KEY_R & Angular Velocity Zeroing ---")
	_start_test("Suite 3.1: Rewind on empty flight recorder safely returns false")
	var sim: PlanetarySimulation = PlanetarySimulation.new()
	sim.auto_step = false
	sim.setup_simulation(true)
	get_root().add_child(sim)
	await process_frame

	sim.encounter_director.recorder.clear()
	var empty_rewind: bool = LiveSortieBootstrap.trigger_rewind(sim)
	_assert(not empty_rewind, "Rewind with empty recorder gracefully returns false")

	_start_test("Suite 3.2: Rewind restores flight state and zeroes angular velocity")
	sim.encounter_director.recorder.recording_enabled = true
	sim.ship.position = Vector3(100.0, 500.0, -200.0)
	sim.ship.linear_velocity = Vector3(50.0, 10.0, -80.0)
	sim.ship.angular_velocity = Vector3(0.1, 0.2, 0.3)
	sim.encounter_director.thermal.surface_temperature_k = 300.0
	sim.telemetry.surface_temperature_k = 300.0
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_MANUAL)

	# Take a snapshot
	sim.encounter_director.recorder.time_since_last_sample = 0.30
	var sampled: bool = sim.encounter_director.recorder.step_recorder(
		0.01, sim.ship.global_position, sim.ship.linear_velocity, sim.telemetry, sim.guidance.mode
	)
	_assert(sampled, "Snapshot sampled into ring buffer")
	_assert(sim.encounter_director.recorder.count == 1, "Recorder count is 1")

	# Distort ship state severely (e.g. violent spin and thermal spike)
	sim.ship.position = Vector3(999.0, 888.0, 777.0)
	sim.ship.linear_velocity = Vector3(500.0, -300.0, 200.0)
	sim.ship.angular_velocity = Vector3(15.0, -25.0, 30.0) # extreme tumble!
	sim.encounter_director.thermal.surface_temperature_k = 1800.0

	# Trigger rewind
	var rewind_ok: bool = LiveSortieBootstrap.trigger_rewind(sim)
	_assert(rewind_ok, "trigger_rewind returns true")
	_assert_vec3(sim.ship.angular_velocity, Vector3.ZERO, 1e-9, "Ship angular velocity is zeroed!")
	var phys_ang_vel: Vector3 = PhysicsServer3D.body_get_state(
		sim.ship.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY
	)
	_assert_vec3(phys_ang_vel, Vector3.ZERO, 1e-9, "PhysicsServer3D body angular velocity zeroed")
	_assert_vec3(sim.ship.position, Vector3(100.0, 500.0, -200.0), 1e-4, "Ship position restored")
	_assert_vec3(sim.ship.linear_velocity, Vector3(50.0, 10.0, -80.0), 1e-4, "Ship velocity restored")
	_assert_approx(sim.encounter_director.thermal.surface_temperature_k, 300.0, 0.1, "Thermal state restored")

	_start_test("Suite 3.3: 50 consecutive rewinds without state corruption")
	for i in range(50):
		var ok: bool = LiveSortieBootstrap.trigger_rewind(sim)
		_assert(ok, "Consecutive rewind %d succeeded" % i)
		_assert_vec3(sim.ship.angular_velocity, Vector3.ZERO, 1e-9, "Spin zeroed on rewind %d" % i)

	_start_test("Suite 3.4: rewind_flight action during step_simulation zeroes angular velocity")
	sim.ship.process_user_input = true
	sim.ship.angular_velocity = Vector3(12.0, -8.0, 5.0)
	var ev_press: InputEventKey = InputEventKey.new()
	ev_press.physical_keycode = KEY_R
	ev_press.pressed = true
	Input.parse_input_event(ev_press)
	Input.flush_buffered_events()
	sim.step_simulation(DT)
	var ev_release: InputEventKey = InputEventKey.new()
	ev_release.physical_keycode = KEY_R
	ev_release.pressed = false
	Input.parse_input_event(ev_release)
	Input.flush_buffered_events()
	_assert_vec3(sim.ship.angular_velocity, Vector3.ZERO, 1e-9, "rewind_flight action zeroed spin in step_simulation")

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

# -----------------------------------------------------------------------------
# 4. 1,000-Tick Static Heap Memory Stress Test
# -----------------------------------------------------------------------------
func _test_thousand_tick_static_memory() -> void:
	print("\n--- Suite 4: 1,000-Tick Static Heap Memory Stress Test ---")
	_start_test("Suite 4.1: Continuous 1,000-tick live simulation heap stability")
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	await process_frame
	await process_frame

	var visual_rig: Node3D = sim.ship.ensure_visual_rig()
	_assert(visual_rig != null, "Visual rig present")

	# Enable all active subsystems
	var dir: EncounterDirector = sim.encounter_director
	dir.landing_gear.enabled = true
	dir.wind.enabled = true
	dir.power_bus.enabled = true
	dir.propellant.enabled = true
	dir.recorder.recording_enabled = true
	dir.auto_spawn_waves = true
	dir.desired_active_targets = 2
	dir.evasion_enabled = true
	sim.weapon_system.capacitor.enabled = true

	# Warmup 120 ticks
	for i in range(120):
		sim.step_simulation(DT)
		sim.hud.update_hud(sim)
		sim.hud._surface.queue_redraw()
		EntityVisualsBuilder.update_flight_visuals(visual_rig, sim.ship)

	var mem_before: int = OS.get_static_memory_usage()

	# 1,000 stress measurement ticks
	for i in range(1000):
		sim.step_simulation(DT)
		sim.hud.update_hud(sim)
		sim.hud._surface.queue_redraw()
		EntityVisualsBuilder.update_flight_visuals(visual_rig, sim.ship)

	var mem_after: int = OS.get_static_memory_usage()
	var delta: int = mem_after - mem_before
	print("  Static memory delta over 1,000 stress ticks: %d bytes (before=%d, after=%d)" % [
		delta, mem_before, mem_after
	])
	_assert(delta <= 0, "Static heap delta <= 0 bytes (got %d)" % delta)

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

# -----------------------------------------------------------------------------
# 5. Terrain Seam Continuity Adversarial Probe
# -----------------------------------------------------------------------------
func _test_seam_continuity_probe() -> void:
	print("\n--- Suite 5: Terrain Seam Continuity Adversarial Probe ---")
	_start_test("Suite 5.1: High-density 100-sample probe along all 12 cube face shared edges")
	TerrainMeshBuilder.init_builder()
	var seed_val: int = 1337
	var freq: float = 64.0
	var amp: float = 500.0

	var edges: Array = [
		{"fA": 0, "uvA": func(t: float) -> Vector2: return Vector2(1.0, t), "fB": 5, "uvB": func(t: float) -> Vector2: return Vector2(-1.0, t), "name": "+X Right <-> -Z Left"},
		{"fA": 0, "uvA": func(t: float) -> Vector2: return Vector2(-1.0, t), "fB": 4, "uvB": func(t: float) -> Vector2: return Vector2(1.0, t), "name": "+X Left <-> +Z Right"},
		{"fA": 0, "uvA": func(t: float) -> Vector2: return Vector2(t, 1.0), "fB": 2, "uvB": func(t: float) -> Vector2: return Vector2(-t, 1.0), "name": "+X Top <-> +Y Top"},
		{"fA": 0, "uvA": func(t: float) -> Vector2: return Vector2(t, -1.0), "fB": 3, "uvB": func(t: float) -> Vector2: return Vector2(t, 1.0), "name": "+X Bottom <-> -Y Top"},
		{"fA": 1, "uvA": func(t: float) -> Vector2: return Vector2(1.0, t), "fB": 4, "uvB": func(t: float) -> Vector2: return Vector2(-1.0, t), "name": "-X Right <-> +Z Left"},
		{"fA": 1, "uvA": func(t: float) -> Vector2: return Vector2(-1.0, t), "fB": 5, "uvB": func(t: float) -> Vector2: return Vector2(1.0, t), "name": "-X Left <-> -Z Right"},
		{"fA": 1, "uvA": func(t: float) -> Vector2: return Vector2(t, 1.0), "fB": 2, "uvB": func(t: float) -> Vector2: return Vector2(t, -1.0), "name": "-X Top <-> +Y Bottom"},
		{"fA": 1, "uvA": func(t: float) -> Vector2: return Vector2(t, -1.0), "fB": 3, "uvB": func(t: float) -> Vector2: return Vector2(-t, -1.0), "name": "-X Bottom <-> -Y Bottom"},
		{"fA": 2, "uvA": func(t: float) -> Vector2: return Vector2(-1.0, t), "fB": 5, "uvB": func(t: float) -> Vector2: return Vector2(-t, 1.0), "name": "+Y Left <-> -Z Top"},
		{"fA": 2, "uvA": func(t: float) -> Vector2: return Vector2(1.0, t), "fB": 4, "uvB": func(t: float) -> Vector2: return Vector2(t, 1.0), "name": "+Y Right <-> +Z Top"},
		{"fA": 3, "uvA": func(t: float) -> Vector2: return Vector2(1.0, t), "fB": 5, "uvB": func(t: float) -> Vector2: return Vector2(-t, -1.0), "name": "-Y Left <-> -Z Bottom"},
		{"fA": 3, "uvA": func(t: float) -> Vector2: return Vector2(-1.0, t), "fB": 4, "uvB": func(t: float) -> Vector2: return Vector2(t, -1.0), "name": "-Y Right <-> +Z Bottom"}
	]

	var max_diff: float = 0.0
	for edge in edges:
		var fA: int = edge["fA"]
		var fB: int = edge["fB"]
		var uvA_fn: Callable = edge["uvA"]
		var uvB_fn: Callable = edge["uvB"]

		for step in range(101):
			var t: float = -1.0 + 2.0 * float(step) / 100.0
			var pA: Vector2 = uvA_fn.call(t)
			var pB: Vector2 = uvB_fn.call(t)
			var dirA: Vector3 = PlanetMath.face_uv_to_sphere_dir(fA, pA)
			var dirB: Vector3 = PlanetMath.face_uv_to_sphere_dir(fB, pB)
			var hA: float = PlanetMath.get_terrain_height(dirA, PLANET_RADIUS, seed_val, freq, amp)
			var hB: float = PlanetMath.get_terrain_height(dirB, PLANET_RADIUS, seed_val, freq, amp)
			var diff: float = absf(hA - hB)
			if diff > max_diff:
				max_diff = diff

	print("  Maximum elevation discontinuity across 1,212 seam probe points: %.8f m" % max_diff)
	_assert(max_diff < 1e-6, "Seam cliff discontinuity across all edges is 0.000000 m")

# -----------------------------------------------------------------------------
# 6. Production Script Architecture Audit
# -----------------------------------------------------------------------------
func _test_production_script_architecture() -> void:
	print("\n--- Suite 6: Production Script Architecture Audit ---")
	_start_test("Suite 6.1: All 43 scripts declare class_name and stay <= 250 lines")
	var prod_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			prod_files.append(file)

	_assert_int(prod_files.size(), 43, "Exactly 43 production scripts present")

	var ceilings: Dictionary = {
		"PlanetarySimulation.gd": 248,
		"PlanetStreamer.gd": 240,
		"ChunkTaskScheduler.gd": 248,
		"CockpitHUD.gd": 248,
		"SpaceshipController.gd": 220,
		"PlanetManager.gd": 242,
		"FlightGuidanceSystem.gd": 245,
		"MobileTouchController.gd": 95,
		"MobileTouchOverlay.gd": 125,
	}

	for file in prod_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var lines: PackedStringArray = text.split("\n")
		var count: int = lines.size()
		if text.ends_with("\n"):
			count -= 1
		var first_line: String = lines[0].strip_edges()
		_assert(first_line.begins_with("class_name "), "%s declares class_name on line 1" % file)
		var max_allowed: int = ceilings.get(file, 250)
		_assert(count <= max_allowed, "%s has %d lines (ceiling %d)" % [file, count, max_allowed])
