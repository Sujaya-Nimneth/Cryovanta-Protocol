extends SceneTree

## Reviewer 2 Phase E Adversarial Stress & Integrity Verification Harness
## Tests counter-examples, stress bounds, and zero-allocation hot paths.

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test: String = ""

const DT: float = 1.0 / 120.0
const PLANET_RADIUS: float = 100_000.0

func _init() -> void:
	print("==================================================================")
	print("REVIEWER 2 PHASE E: ADVERSARIAL INTEGRITY & STRESS HARNESS")
	print("==================================================================")
	await process_frame

	test_seam_counter_example()
	test_rewind_stress_and_edge_cases()
	test_touch_overlay_stress_and_coexistence()
	test_compute_chunk_dispatcher_corrupt_buffers()
	await test_live_auto_step_1000_ticks_zero_heap_delta()

	_print_summary()
	quit(0 if failed_assertions == 0 else 1)

func _start(name: String) -> void:
	current_test = name
	print("RUNNING: %s" % name)

func _assert(cond: bool, msg: String) -> void:
	total_assertions += 1
	if cond:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("  [FAIL] %s: %s" % [current_test, msg])

func _assert_approx(a: float, b: float, tol: float, msg: String) -> void:
	var delta: float = absf(a - b)
	_assert(delta <= tol, "%s (expected ~%.6f, got ~%.6f, delta=%.8f > tol=%.8f)" % [msg, b, a, delta, tol])

func _print_summary() -> void:
	print("==================================================================")
	print("SUMMARY: %d total assertions, %d passed, %d failed" % [total_assertions, passed_assertions, failed_assertions])
	print("==================================================================")

func test_seam_counter_example() -> void:
	_start("1. Seam Continuity Counter-Example (Negative Control)")
	# Verify that if seed_face_stride != 0, a seam discontinuity occurs,
	# confirming Tier 4 is sensitive and not self-certifying.
	TerrainMeshBuilder.init_builder()
	var seed_val: int = 1337
	var freq: float = 64.0
	var amp: float = 500.0

	# With seed_face_stride = 0:
	var uvA: Vector2 = Vector2(1.0, 0.0)
	var uvB: Vector2 = Vector2(-1.0, 0.0)
	var dirA: Vector3 = PlanetMath.face_uv_to_sphere_dir(0, uvA)
	var dirB: Vector3 = PlanetMath.face_uv_to_sphere_dir(5, uvB)
	var hA: float = PlanetMath.get_terrain_height(dirA, PLANET_RADIUS, seed_val, freq, amp)
	var hB: float = PlanetMath.get_terrain_height(dirB, PLANET_RADIUS, seed_val, freq, amp)
	_assert(absf(hA - hB) < 1e-6, "With seed_face_stride=0, height delta is 0.000000 m")

	# Simulating what happens if faces used distinct seeds (face stride = 100):
	var hA_stride: float = PlanetMath.get_terrain_height(dirA, PLANET_RADIUS, seed_val + 0 * 100, freq, amp)
	var hB_stride: float = PlanetMath.get_terrain_height(dirB, PLANET_RADIUS, seed_val + 5 * 100, freq, amp)
	var discontinuity: float = absf(hA_stride - hB_stride)
	_assert(discontinuity > 5.0, "With face stride=100, significant cliff discontinuity occurs (%.2f m > 5m)" % discontinuity)

func test_rewind_stress_and_edge_cases() -> void:
	_start("2. Rewind Edge Cases & 10,000 Iteration Zero Allocation")
	# Null safety
	_assert(LiveSortieBootstrap.trigger_rewind(null) == false, "trigger_rewind(null) returns false safely")

	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)

	# Empty recorder
	sim.encounter_director.recorder.clear()
	_assert(LiveSortieBootstrap.trigger_rewind(sim) == false, "trigger_rewind on empty recorder returns false")

	# Single snapshot
	sim.encounter_director.recorder.recording_enabled = true
	sim.encounter_director.recorder.record_snapshot(Vector3(10.0, 20.0, 30.0), Vector3(1.0, 2.0, 3.0), 1.0, 300.0, 1.0, 0)
	_assert(LiveSortieBootstrap.trigger_rewind(sim) == true, "trigger_rewind on valid snapshot returns true")
	_assert(sim.ship.angular_velocity == Vector3.ZERO, "Ship angular velocity zeroed on rewind")

	# 10,000 rewind triggers zero heap allocation
	var mem_before: int = OS.get_static_memory_usage()
	for i in range(10000):
		LiveSortieBootstrap.trigger_rewind(sim)
	var mem_after: int = OS.get_static_memory_usage()
	_assert(mem_after - mem_before <= 0, "10,000 trigger_rewind calls zero static heap delta (delta=%d bytes)" % (mem_after - mem_before))

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

func test_touch_overlay_stress_and_coexistence() -> void:
	_start("3. Touch / Mouse Coexistence & 10,000 Transition Zero Allocation")
	var overlay: MobileTouchOverlay = MobileTouchOverlay.new()
	var controller: MobileTouchController = MobileTouchController.new()
	var vp_size: Vector2 = Vector2(1920.0, 1080.0)

	# Out-of-order touch release
	overlay.handle_touch_point(true, 5, Vector2(200.0, 500.0), vp_size, controller)
	_assert(controller.enabled == true, "Non-zero touch index enables controller")
	overlay.handle_touch_point(false, 5, Vector2(200.0, 500.0), vp_size, controller)
	_assert(controller.enabled == false, "Releasing non-zero touch resets enabled")

	# Rapid mouse press & release 10,000 times
	var mem_b: int = OS.get_static_memory_usage()
	for i in range(10000):
		overlay.handle_touch_point(true, 0, Vector2(400.0, 600.0), vp_size, controller)
		overlay.handle_touch_point(false, 0, Vector2(400.0, 600.0), vp_size, controller)
	var mem_a: int = OS.get_static_memory_usage()
	_assert(mem_a - mem_b <= 0, "10,000 touch/mouse toggles zero static heap delta (delta=%d bytes)" % (mem_a - mem_b))

func test_compute_chunk_dispatcher_corrupt_buffers() -> void:
	_start("4. ComputeChunkDispatcher Corrupt Buffer Resilience")
	var dispatcher: ComputeChunkDispatcher = ComputeChunkDispatcher.new(true)
	# Buffer size too small
	var bad_bytes: PackedByteArray = PackedByteArray()
	bad_bytes.resize(100)
	_assert(dispatcher.unpack_std430_vertex_buffer(bad_bytes) == false, "Short buffer rejected")
	# Empty buffer
	_assert(dispatcher.unpack_std430_vertex_buffer(PackedByteArray()) == false, "Empty buffer rejected")
	# Array mapping constants
	_assert(dispatcher._gpu_mesh_arrays.size() == Mesh.ARRAY_MAX, "_gpu_mesh_arrays size == ARRAY_MAX")

func test_live_auto_step_1000_ticks_zero_heap_delta() -> void:
	_start("5. Full Live auto_step=true Simulation 1,000 Ticks Zero Static Memory Delta")
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = true
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	await process_frame
	await process_frame

	# Verify live sortie bootstrapped
	_assert(sim.ship.process_user_input == true, "User input active")
	_assert(sim.encounter_director.mission.stage == MissionScenarioRunner.STAGE_WAYPOINT_RECON, "Sortie in Recon stage")

	# Warmup 120 ticks
	for i in range(120):
		sim.step_simulation(DT)
		sim.hud.update_hud(sim)
		sim.hud._surface.queue_redraw()

	var mem_before: int = OS.get_static_memory_usage()

	# 1,000 measurement ticks under full live sortie conditions
	for i in range(1000):
		sim.step_simulation(DT)
		sim.hud.update_hud(sim)
		sim.hud._surface.queue_redraw()

	var mem_after: int = OS.get_static_memory_usage()
	var delta: int = mem_after - mem_before
	print("  Live auto_step=true static memory delta over 1,000 ticks: %d bytes (before=%d, after=%d)" % [
		delta, mem_before, mem_after
	])
	_assert(delta <= 0, "Live auto_step=true 1,000 ticks static memory delta <= 0 bytes (got %d)" % delta)

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()
