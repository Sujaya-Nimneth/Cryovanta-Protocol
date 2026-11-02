extends SceneTree

## Phase 15 headless verification: live sortie, controls coexistence, compute mapping, seam continuity, zero heap growth.

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
	print("Cryovanta Protocol: Phase 15 Headless Verification Suite (Tiers 1-5)")
	print("==================================================================")
	await process_frame
	await _run_tier_1()
	_run_tier_2()
	_run_tier_3()
	_run_tier_4()
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

func _assert_vec2(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
	_assert(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [
		message, str(expected), str(actual)
	])

func _print_summary() -> void:
	print("\n==================================================================")
	print("PHASE 15 TEST SUITE EXECUTION SUMMARY")
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
	print("\n--- Tier 1: Live Sortie Activation & Backward Compatibility Invariance ---")
	_start_test("Tier 1.1: Live auto_step = true sortie bootstrap & subsystem activation")
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = true
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	await process_frame
	await process_frame

	_assert(sim.ship != null, "Ship instantiated")
	_assert(sim.ship.process_user_input == true, "Ship process_user_input enabled in live sortie")
	_assert(sim.ship.mass >= 1000.0, "Ship mass >= 1000.0 kg in live sortie (mass=%.1f)" % sim.ship.mass)
	_assert_approx(sim.ship.mass, 1600.0, 1.0, "Ship mass matches propellant wet mass (1600.0 kg)")
	_assert_vec3(sim.ship.inertia, Vector3(2000.0, 2000.0, 3000.0), 1e-4, "Ship principal inertia set to Vector3(2000, 2000, 3000)")
	_assert(sim.ship.visual_rig != null, "Ship visual rig instantiated")
	_assert(sim.ship.visual_rig.is_inside_tree(), "Ship visual rig attached inside tree")

	var dir: EncounterDirector = sim.encounter_director
	_assert(dir != null, "EncounterDirector present")
	_assert(dir.mission != null, "MissionScenarioRunner present")
	_assert_int(dir.mission.stage, MissionScenarioRunner.STAGE_WAYPOINT_RECON, "Mission sortie starts in STAGE_WAYPOINT_RECON (1)")

	_assert(dir.power_bus != null and dir.power_bus.enabled, "ShipPowerBusModel enabled in live sortie")
	var expected_sun: Vector3 = sim.environment.sun_light.global_transform.basis.z.normalized()
	_assert_vec3(dir.power_bus.sun_direction, expected_sun, 1e-4, "Power bus sun direction synchronized with sun light basis")

	_assert(dir.propellant != null and dir.propellant.enabled, "PropellantMassModel enabled in live sortie")
	_assert(dir.wind != null and dir.wind.enabled, "PlanetaryWindModel enabled in live sortie")
	_assert(dir.landing_gear != null and dir.landing_gear.enabled, "LandingGearModel enabled in live sortie")
	_assert(dir.landing_gear.deployed == false, "Landing gear retracted for cruise spawn")
	_assert_approx(dir.landing_gear.deploy_progress, 0.0, 1e-4, "Landing gear deploy progress is 0.0")
	_assert(dir.recorder != null and dir.recorder.recording_enabled, "FlightRecorderRingBuffer recording enabled in live sortie")
	_assert(dir.evasion_enabled, "Drone evasion enabled in live sortie")
	_assert(sim.weapon_system != null and sim.weapon_system.capacitor.enabled, "Weapon heat capacitor enabled in live sortie")

	_assert(sim.planet_streamer != null, "PlanetStreamer present")
	var loaded_chunks: int = 0
	for b in sim.planet_streamer.mesh_loaded:
		if b == 1:
			loaded_chunks += 1
	_assert(loaded_chunks > 0, "Surface terrain chunks bootstrapped before frame 0 (loaded=%d)" % loaded_chunks)

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

	_start_test("Tier 1.2: Backward compatibility invariance with auto_step = false")
	var sim_manual: PlanetarySimulation = packed.instantiate()
	sim_manual.auto_step = false
	sim_manual.synchronous_streaming = true
	get_root().add_child(sim_manual)
	await process_frame

	_assert(sim_manual.ship.process_user_input == false, "Ship process_user_input remains false when auto_step = false")
	_assert_approx(sim_manual.ship.mass, 1000.0, 1e-4, "Ship baseline dry mass remains 1000.0 kg")
	_assert_vec3(sim_manual.ship.inertia, Vector3(2000.0, 2000.0, 3000.0), 1e-4, "Ship baseline inertia maintained")
	_assert(sim_manual.encounter_director.mission.stage == MissionScenarioRunner.STAGE_INACTIVE, "Mission remains STAGE_INACTIVE when auto_step = false")

	sim_manual.destroy()
	get_root().remove_child(sim_manual)
	sim_manual.free()

func _run_tier_2() -> void:
	print("\n--- Tier 2: Touch/Mouse Release Coexistence & Flight Rewind ---")
	_start_test("Tier 2.1: Multi-touch and mouse press & release resets touch_controller.enabled = false")
	var overlay: MobileTouchOverlay = MobileTouchOverlay.new()
	var controller: MobileTouchController = MobileTouchController.new()
	var vp_size: Vector2 = Vector2(1920.0, 1080.0)

	_assert(controller.enabled == false, "Controller initially disabled")

	# Touch 0 press on left joystick zone
	overlay.handle_touch_point(true, 0, Vector2(300.0, 600.0), vp_size, controller)
	_assert(controller.enabled == true, "Left touch press enables touch controller")
	_assert_int(overlay.left_touch_index, 0, "Left touch index tracked as 0")

	# Touch 1 press on right joystick zone
	overlay.handle_touch_point(true, 1, Vector2(1500.0, 600.0), vp_size, controller)
	_assert(controller.enabled == true, "Right touch press keeps controller enabled")
	_assert_int(overlay.right_touch_index, 1, "Right touch index tracked as 1")

	# Release touch 0 while touch 1 is still active
	overlay.handle_touch_point(false, 0, Vector2(300.0, 600.0), vp_size, controller)
	_assert(controller.enabled == true, "Controller stays enabled while touch 1 is still down")
	_assert_int(overlay.left_touch_index, -1, "Left touch index reset to -1")

	# Release touch 1
	overlay.handle_touch_point(false, 1, Vector2(1500.0, 600.0), vp_size, controller)
	_assert(controller.enabled == false, "Releasing all touches resets controller.enabled to false")
	_assert_int(overlay.right_touch_index, -1, "Right touch index reset to -1")

	# Test desktop mouse single-click emulation (touch index 0)
	overlay.handle_touch_point(true, 0, Vector2(400.0, 500.0), vp_size, controller)
	_assert(controller.enabled == true, "Desktop mouse click enables controller")
	overlay.handle_touch_point(false, 0, Vector2(400.0, 500.0), vp_size, controller)
	_assert(controller.enabled == false, "Desktop mouse release resets controller.enabled to false, restoring keyboard flight")

	# Reset overlay
	overlay.handle_touch_point(true, 0, Vector2(400.0, 500.0), vp_size, controller)
	_assert(controller.enabled == true, "Controller enabled before overlay reset")
	overlay.reset(controller)
	_assert(controller.enabled == false, "overlay.reset() forces controller.enabled to false")
	_assert_int(overlay.left_touch_index, -1, "Left touch index reset")
	_assert_int(overlay.right_touch_index, -1, "Right touch index reset")

	_start_test("Tier 2.2: KEY_R rewind action registration & angular velocity zeroing")
	FlightInputBindings.ensure_default_actions()
	_assert(InputMap.has_action(&"rewind_flight"), "FlightInputBindings registers rewind_flight action")
	var key_r_found: bool = false
	for event in InputMap.action_get_events(&"rewind_flight"):
		if event is InputEventKey and event.physical_keycode == KEY_R:
			key_r_found = true
			break
	_assert(key_r_found, "rewind_flight action mapped to KEY_R")

	# Test rewind restores flight snapshot and zeroes angular velocity
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)

	var rec: FlightRecorderRingBuffer = sim.encounter_director.recorder
	rec.recording_enabled = true
	rec.clear()

	# Spin ship and record snapshot
	sim.ship.global_position = Vector3(0.0, 1000.0, 0.0)
	sim.ship.linear_velocity = Vector3(0.0, 0.0, -150.0)
	sim.ship.angular_velocity = Vector3(1.2, -0.8, 2.5)
	rec.record_snapshot(
		sim.ship.global_position,
		sim.ship.linear_velocity,
		1.0,
		290.0,
		1.0,
		FlightGuidanceSystem.MODE_MANUAL
	)
	_assert(rec.count > 0, "FlightRecorder captured snapshot")

	# Mutate ship state
	sim.ship.global_position = Vector3(500.0, 2000.0, 300.0)
	sim.ship.linear_velocity = Vector3(50.0, 10.0, -20.0)
	sim.ship.angular_velocity = Vector3(5.0, 4.0, 3.0)

	var rewind_ok: bool = LiveSortieBootstrap.trigger_rewind(sim)
	_assert(rewind_ok, "trigger_rewind succeeded")
	_assert_vec3(sim.ship.global_position, Vector3(0.0, 1000.0, 0.0), 1e-3, "Ship position restored by rewind")
	_assert_vec3(sim.ship.linear_velocity, Vector3(0.0, 0.0, -150.0), 1e-3, "Ship linear velocity restored by rewind")
	_assert_vec3(sim.ship.angular_velocity, Vector3.ZERO, 1e-6, "Ship angular velocity zeroed on rewind")

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

func _run_tier_3() -> void:
	print("\n--- Tier 3: Vulkan Compute Mesh Upload Buffer Mapping ---")
	_start_test("Tier 3.1: std430 storage buffer layout and vertex counts")
	var dispatcher: ComputeChunkDispatcher = ComputeChunkDispatcher.new(true)
	_assert_int(ComputeChunkDispatcher.VERTEX_COUNT, 1156, "Vertex count is 1156 (34x34 grid)")
	_assert_int(TerrainMeshBuilder._indices.size(), TerrainMeshBuilder.INDEX_COUNT, "TerrainMeshBuilder._indices size matches TerrainMeshBuilder.INDEX_COUNT (6534)")
	_assert_int(TerrainMeshBuilder.INDEX_COUNT, 6534, "TerrainMeshBuilder.INDEX_COUNT is 6534 (33x33 quads * 6)")

	_start_test("Tier 3.2: _gpu_mesh_arrays sizing and Mesh.ARRAY_* enum index mapping")
	_assert_int(dispatcher._gpu_mesh_arrays.size(), Mesh.ARRAY_MAX, "_gpu_mesh_arrays sized to Mesh.ARRAY_MAX (%d)" % Mesh.ARRAY_MAX)
	_assert_int(Mesh.ARRAY_VERTEX, 0, "Mesh.ARRAY_VERTEX == 0")
	_assert_int(Mesh.ARRAY_NORMAL, 1, "Mesh.ARRAY_NORMAL == 1")
	_assert_int(Mesh.ARRAY_TEX_UV, 4, "Mesh.ARRAY_TEX_UV == 4")
	_assert_int(Mesh.ARRAY_INDEX, 12, "Mesh.ARRAY_INDEX == 12")
	_assert_int(Mesh.ARRAY_MAX, 13, "Mesh.ARRAY_MAX == 13")

	# Populate synthetic vertex data with distinct coordinates and UVs
	for i in range(ComputeChunkDispatcher.VERTEX_COUNT):
		var fi: float = float(i)
		dispatcher.last_vertices[i] = Vector4(fi * 0.1, fi * 0.2, fi * 0.3, fi / 1156.0)
		dispatcher.last_normals[i] = Vector4(0.0, 1.0, 0.0, 1.0 - (fi / 1156.0))

	var mesh: ArrayMesh = ArrayMesh.new()
	dispatcher._upload_vertex_buffer_to_mesh(mesh)

	_assert_int(mesh.get_surface_count(), 1, "ArrayMesh has 1 surface added")
	_assert_int(mesh.surface_get_array_len(0), 1156, "Surface vertex count is 1156")
	_assert_int(mesh.surface_get_array_index_len(0), TerrainMeshBuilder.INDEX_COUNT, "Surface index count is 6534")

	var surf_arrays: Array = mesh.surface_get_arrays(0)
	_assert(surf_arrays.size() == Mesh.ARRAY_MAX, "Surface arrays size matches Mesh.ARRAY_MAX")

	var v_arr: PackedVector3Array = surf_arrays[Mesh.ARRAY_VERTEX]
	var n_arr: PackedVector3Array = surf_arrays[Mesh.ARRAY_NORMAL]
	var uv_arr: PackedVector2Array = surf_arrays[Mesh.ARRAY_TEX_UV]
	var idx_arr: PackedInt32Array = surf_arrays[Mesh.ARRAY_INDEX]

	_assert_int(v_arr.size(), 1156, "Uploaded vertex array contains 1156 elements at Mesh.ARRAY_VERTEX (0)")
	_assert_int(n_arr.size(), 1156, "Uploaded normal array contains 1156 elements at Mesh.ARRAY_NORMAL (1)")
	_assert_int(uv_arr.size(), 1156, "Uploaded UV array contains 1156 elements at Mesh.ARRAY_TEX_UV (4)")
	_assert_int(idx_arr.size(), TerrainMeshBuilder.INDEX_COUNT, "Uploaded index array contains 6534 elements at Mesh.ARRAY_INDEX (12)")

	# Spot check vertex, normal, and UV accuracy
	_assert_vec3(v_arr[10], Vector3(1.0, 2.0, 3.0), 1e-4, "Vertex 10 position matches (1.0, 2.0, 3.0)")
	_assert_vec3(n_arr[10], Vector3(0.0, 1.0, 0.0), 1e-4, "Normal 10 matches (0.0, 1.0, 0.0)")
	_assert_vec2(uv_arr[10], Vector2(10.0 / 1156.0, 1.0 - 10.0 / 1156.0), 1e-4, "UV 10 matches (p.w, n.w)")

func _run_tier_4() -> void:
	print("\n--- Tier 4: Planetary Terrain Seam Continuity ---")
	_start_test("Tier 4.1: Terrain frequency and seed face stride invariants")
	_assert_approx(PlanetMath.TERRAIN_FREQUENCY, 64.0, 1e-4, "PlanetMath.TERRAIN_FREQUENCY is 64.0")
	var streamer: PlanetStreamer = PlanetStreamer.new()
	_assert_int(streamer.seed_face_stride, 0, "PlanetStreamer default seed_face_stride is 0 (eliminating seam cliffs)")
	_assert_approx(streamer.noise_frequency, 64.0, 1e-4, "PlanetStreamer default noise_frequency is 64.0")
	streamer.free()

	_start_test("Tier 4.2: 0.000000 m seam cliff discontinuity across all 12 cube face shared edges")
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
	_assert_int(edges.size(), 12, "All 12 cube face shared edges defined")

	var sample_steps: int = 50
	var max_elevation_delta: float = 0.0

	for edge in edges:
		var fA: int = edge["fA"]
		var fB: int = edge["fB"]
		var uvA_fn: Callable = edge["uvA"]
		var uvB_fn: Callable = edge["uvB"]
		var edge_name: String = edge["name"]

		for s in range(sample_steps + 1):
			var t: float = -1.0 + 2.0 * float(s) / float(sample_steps)
			var uvA: Vector2 = uvA_fn.call(t)
			var uvB: Vector2 = uvB_fn.call(t)

			var dirA: Vector3 = PlanetMath.face_uv_to_sphere_dir(fA, uvA)
			var dirB: Vector3 = PlanetMath.face_uv_to_sphere_dir(fB, uvB)
			_assert(dirA.distance_to(dirB) < 1e-5, "%s [t=%.2f]: Sphere direction continuity" % [edge_name, t])

			var hA: float = PlanetMath.get_terrain_height(dirA, PLANET_RADIUS, seed_val, freq, amp)
			var hB: float = PlanetMath.get_terrain_height(dirB, PLANET_RADIUS, seed_val, freq, amp)
			var h_delta: float = absf(hA - hB)
			if h_delta > max_elevation_delta:
				max_elevation_delta = h_delta
			_assert(h_delta < 1e-6, "%s [t=%.2f]: Seam elevation delta == 0.000000 m (delta=%.8f)" % [edge_name, t, h_delta])

			var expected_h: float = PLANET_RADIUS + amp * TerrainMeshBuilder.fbm4(dirA * freq, seed_val).x
			_assert_approx(hA, expected_h, 1e-4, "%s [t=%.2f]: Elevation matches PlanetMath formula" % [edge_name, t])

	print("  Seam continuity verified: max edge elevation discontinuity = %.8f m" % max_elevation_delta)

func _run_tier_5() -> void:
	print("\n--- Tier 5: 1,000-Tick Full-Stack Static Memory Gate ---")
	_start_test("Tier 5.1: Zero steady-state static memory growth over 1,000 live simulation ticks")
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	await process_frame
	await process_frame

	# Stabilize simulation steady state
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.freeze = true
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3.ZERO
	sim.ship.angular_velocity = Vector3.ZERO
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_MANUAL)

	# Active flight & combat subsystems
	var dir: EncounterDirector = sim.encounter_director
	dir.landing_gear.enabled = true
	dir.wind.enabled = true
	dir.power_bus.enabled = true
	dir.propellant.enabled = true
	dir.recorder.recording_enabled = true
	dir.auto_spawn_waves = true
	dir.desired_active_targets = 2
	dir.evasion_enabled = true
	dir.target_initial_health = 1.0e9
	sim.weapon_system.capacitor.enabled = true

	# Ensure ship 3D visuals and HUD are initialized
	var visual_rig: Node3D = sim.ship.ensure_visual_rig()
	_assert(visual_rig != null, "Visual rig active during memory gate")
	sim.hud.update_hud(sim)
	sim.hud._surface.queue_redraw()

	# Warmup: 120 ticks to initialize caches, buffers, and dynamic pools
	for i in range(120):
		sim.step_simulation(DT)
		sim.hud.update_hud(sim)
		sim.hud._surface.queue_redraw()
		EntityVisualsBuilder.update_flight_visuals(visual_rig, sim.ship)

	var mem_before: int = OS.get_static_memory_usage()

	# 1,000 live simulation measurement ticks
	for i in range(1000):
		sim.step_simulation(DT)
		sim.hud.update_hud(sim)
		sim.hud._surface.queue_redraw()
		EntityVisualsBuilder.update_flight_visuals(visual_rig, sim.ship)

	var mem_after: int = OS.get_static_memory_usage()
	var delta: int = mem_after - mem_before
	print("  Static memory delta over 1,000 live ticks: %d bytes (before=%d, after=%d)" % [
		delta, mem_before, mem_after
	])
	_assert(delta <= 0, "Zero runtime static heap growth over 1,000 live ticks (delta=%d <= 0)" % delta)

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()
