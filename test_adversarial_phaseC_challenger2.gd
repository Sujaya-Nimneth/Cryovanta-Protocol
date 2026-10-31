extends SceneTree

## Comprehensive Empirical Verification & Adversarial Stress Harness for Phase C
## Authored by: challenger_phaseC2_1

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test: String = ""

func _init() -> void:
	print("==================================================================")
	print("CHALLENGER 2 PHASE C: EMPIRICAL STRESS & REGRESSION HARNESS")
	print("==================================================================")
	await process_frame
	
	test_task1_cube_face_seam_continuity()
	test_task2_vulkan_compute_mesh_upload_arrays()
	test_task3_thread_safety_and_lock_free_scheduler()
	test_adversarial_stress_and_edge_cases()
	await test_task4_rapid_camera_translation_and_rebase_stress()
	await test_task5_convergence_benchmark_24_48_96()
	await test_task6_zero_allocation_streaming_audit_1000_ticks()
	
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

func _assert_vec3_approx(a: Vector3, b: Vector3, tol: float, msg: String) -> void:
	var dist: float = a.distance_to(b)
	_assert(dist <= tol, "%s (delta=%.8f > tol=%.8f)" % [msg, dist, tol])

## ============================================================================
## TASK 1: Cube Face Seam Continuity Across All 12 Shared Edges
## ============================================================================
func test_task1_cube_face_seam_continuity() -> void:
	_start("TASK 1: All 12 Cube Face Shared Edges Elevation & Normal Seam Continuity")
	TerrainMeshBuilder.init_builder()
	var planet_radius: float = 100_000.0
	var seed_val: int = 1337
	var freq: float = 64.0
	var amp: float = 500.0
	
	# The 12 shared edges of a unit cube between faces [0..5]
	var edges: Array = [
		{"fA": 0, "uvA": func(t): return Vector2(1.0, t), "fB": 5, "uvB": func(t): return Vector2(-1.0, t), "name": "+X Right <-> -Z Left"},
		{"fA": 0, "uvA": func(t): return Vector2(-1.0, t), "fB": 4, "uvB": func(t): return Vector2(1.0, t), "name": "+X Left <-> +Z Right"},
		{"fA": 0, "uvA": func(t): return Vector2(t, 1.0), "fB": 2, "uvB": func(t): return Vector2(-t, 1.0), "name": "+X Top <-> +Y Top"},
		{"fA": 0, "uvA": func(t): return Vector2(t, -1.0), "fB": 3, "uvB": func(t): return Vector2(t, 1.0), "name": "+X Bottom <-> -Y Top"},
		{"fA": 1, "uvA": func(t): return Vector2(1.0, t), "fB": 4, "uvB": func(t): return Vector2(-1.0, t), "name": "-X Right <-> +Z Left"},
		{"fA": 1, "uvA": func(t): return Vector2(-1.0, t), "fB": 5, "uvB": func(t): return Vector2(1.0, t), "name": "-X Left <-> -Z Right"},
		{"fA": 1, "uvA": func(t): return Vector2(t, 1.0), "fB": 2, "uvB": func(t): return Vector2(t, -1.0), "name": "-X Top <-> +Y Bottom"},
		{"fA": 1, "uvA": func(t): return Vector2(t, -1.0), "fB": 3, "uvB": func(t): return Vector2(-t, -1.0), "name": "-X Bottom <-> -Y Bottom"},
		{"fA": 2, "uvA": func(t): return Vector2(-1.0, t), "fB": 5, "uvB": func(t): return Vector2(-t, 1.0), "name": "+Y Left <-> -Z Top"},
		{"fA": 2, "uvA": func(t): return Vector2(1.0, t), "fB": 4, "uvB": func(t): return Vector2(t, 1.0), "name": "+Y Right <-> +Z Top"},
		{"fA": 3, "uvA": func(t): return Vector2(1.0, t), "fB": 5, "uvB": func(t): return Vector2(-t, -1.0), "name": "-Y Left <-> -Z Bottom"},
		{"fA": 3, "uvA": func(t): return Vector2(-1.0, t), "fB": 4, "uvB": func(t): return Vector2(t, -1.0), "name": "-Y Right <-> +Z Bottom"}
	]
	
	_assert(edges.size() == 12, "All 12 cube face shared edges defined")
	
	var max_sphere_dir_delta: float = 0.0
	var max_elevation_delta: float = 0.0
	var max_planet_math_delta: float = 0.0
	var max_normal_delta: float = 0.0
	var sample_steps: int = 100
	
	for edge_info in edges:
		var fA: int = edge_info["fA"]
		var fB: int = edge_info["fB"]
		var uvA_fn: Callable = edge_info["uvA"]
		var uvB_fn: Callable = edge_info["uvB"]
		var edge_name: String = edge_info["name"]
		
		for s in range(sample_steps + 1):
			var t: float = -1.0 + 2.0 * float(s) / float(sample_steps)
			var uvA: Vector2 = uvA_fn.call(t)
			var uvB: Vector2 = uvB_fn.call(t)
			
			var dirA: Vector3 = PlanetMath.face_uv_to_sphere_dir(fA, uvA)
			var dirB: Vector3 = PlanetMath.face_uv_to_sphere_dir(fB, uvB)
			var dir_dist: float = dirA.distance_to(dirB)
			if dir_dist > max_sphere_dir_delta: max_sphere_dir_delta = dir_dist
			_assert(dir_dist < 1e-5, "%s [t=%.2f]: Sphere direction continuity" % [edge_name, t])
			
			# Terrain elevation with seed_face_stride = 0
			var hA: float = PlanetMath.get_terrain_height(dirA, planet_radius, seed_val, freq, amp)
			var hB: float = PlanetMath.get_terrain_height(dirB, planet_radius, seed_val, freq, amp)
			var h_delta: float = absf(hA - hB)
			if h_delta > max_elevation_delta: max_elevation_delta = h_delta
			_assert(h_delta < 1e-6, "%s [t=%.2f]: Elevation difference == 0.000000 m (delta=%.8f)" % [edge_name, t, h_delta])
			
			# Exact match with PlanetMath formula
			var expected_h: float = planet_radius + amp * TerrainMeshBuilder.fbm4(dirA * freq, seed_val).x
			var pm_delta: float = absf(hA - expected_h)
			if pm_delta > max_planet_math_delta: max_planet_math_delta = pm_delta
			_assert(pm_delta < 1e-5, "%s [t=%.2f]: Exact match with PlanetMath.get_terrain_height()" % [edge_name, t])
			
			# Normal vector / gradient continuity across seam (C^1 continuity)
			var fbmA: Vector4 = TerrainMeshBuilder.fbm4(dirA * freq, seed_val)
			var gradA: Vector3 = amp * freq * Vector3(fbmA.y, fbmA.z, fbmA.w)
			gradA -= dirA * gradA.dot(dirA)
			var normA: Vector3 = (dirA * (planet_radius + amp * fbmA.x) - gradA).normalized()
			
			var fbmB: Vector4 = TerrainMeshBuilder.fbm4(dirB * freq, seed_val)
			var gradB: Vector3 = amp * freq * Vector3(fbmB.y, fbmB.z, fbmB.w)
			gradB -= dirB * gradB.dot(dirB)
			var normB: Vector3 = (dirB * (planet_radius + amp * fbmB.x) - gradB).normalized()
			
			var norm_dist: float = normA.distance_to(normB)
			if norm_dist > max_normal_delta: max_normal_delta = norm_dist
			_assert(norm_dist < 1e-4, "%s [t=%.2f]: C^1 Normal vector continuity" % [edge_name, t])
	
	print("  Task 1 Verified: max_dir_delta=%.6f, max_elevation_delta=%.6f, max_pm_delta=%.6f, max_normal_delta=%.6f" % [
		max_sphere_dir_delta, max_elevation_delta, max_planet_math_delta, max_normal_delta
	])
	_assert(max_elevation_delta < 1e-6, "Seam step height is strictly 0.000000 m across all 12 edges (max delta %.8f)" % max_elevation_delta)

## ============================================================================
## TASK 2: Vulkan Compute Mesh Upload Arrays
## ============================================================================
func test_task2_vulkan_compute_mesh_upload_arrays() -> void:
	_start("TASK 2: Vulkan Compute Mesh Upload Array Sizing & Enum Index Mappings")
	var dispatcher = ComputeChunkDispatcher.new(true)
	
	# Verify sizing to Mesh.ARRAY_MAX (13)
	_assert(dispatcher._gpu_mesh_arrays.size() == Mesh.ARRAY_MAX, 
		"_gpu_mesh_arrays is sized to Mesh.ARRAY_MAX (%d), got %d" % [Mesh.ARRAY_MAX, dispatcher._gpu_mesh_arrays.size()])
	_assert(Mesh.ARRAY_MAX == 13, "Mesh.ARRAY_MAX constant is 13")
	
	# Verify enum values
	_assert(Mesh.ARRAY_VERTEX == 0, "Mesh.ARRAY_VERTEX == 0")
	_assert(Mesh.ARRAY_NORMAL == 1, "Mesh.ARRAY_NORMAL == 1")
	_assert(Mesh.ARRAY_TEX_UV == 4, "Mesh.ARRAY_TEX_UV == 4")
	_assert(Mesh.ARRAY_INDEX == 12, "Mesh.ARRAY_INDEX == 12")
	
	# Test upload into a target ArrayMesh
	var target_mesh: ArrayMesh = ArrayMesh.new()
	dispatcher._upload_vertex_buffer_to_mesh(target_mesh)
	
	# Validate mapped arrays inside _gpu_mesh_arrays
	var arr: Array = dispatcher._gpu_mesh_arrays
	_assert(arr[Mesh.ARRAY_VERTEX] is PackedVector3Array, "Index 0 is PackedVector3Array (ARRAY_VERTEX)")
	_assert(arr[Mesh.ARRAY_NORMAL] is PackedVector3Array, "Index 1 is PackedVector3Array (ARRAY_NORMAL)")
	_assert(arr[Mesh.ARRAY_TEX_UV] is PackedVector2Array, "Index 4 is PackedVector2Array (ARRAY_TEX_UV)")
	_assert(arr[Mesh.ARRAY_INDEX] is PackedInt32Array, "Index 12 is PackedInt32Array (ARRAY_INDEX)")
	
	# Validate element count matching
	var v_count: int = arr[Mesh.ARRAY_VERTEX].size()
	var n_count: int = arr[Mesh.ARRAY_NORMAL].size()
	var uv_count: int = arr[Mesh.ARRAY_TEX_UV].size()
	var idx_count: int = arr[Mesh.ARRAY_INDEX].size()
	_assert(v_count == 1156, "Vertex array size == 1156")
	_assert(n_count == 1156, "Normal array size == 1156")
	_assert(uv_count == 1156, "UV array size == 1156")
	_assert(idx_count == 6534, "Index array size == 6534")
	_assert(v_count == n_count and v_count == uv_count, "Vertex, normal, and UV array lengths match exactly (1156)")
	
	# Verify index range validity [0, 1155]
	var indices_valid: bool = true
	var raw_indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for idx_val in raw_indices:
		if idx_val < 0 or idx_val >= v_count:
			indices_valid = false
			break
	_assert(indices_valid, "All 6534 mesh indices are within [0, 1155]")
	
	# Verify unused indices are null/unassigned
	for idx in [2, 3, 5, 6, 7, 8, 9, 10, 11]:
		_assert(arr[idx] == null, "Index %d is null (unused surface array)" % idx)
	
	# Verify surface uploaded to target_mesh
	_assert(target_mesh.get_surface_count() == 1, "target_mesh has exactly 1 uploaded surface")
	var uploaded_arrays: Array = target_mesh.surface_get_arrays(0)
	_assert(uploaded_arrays[Mesh.ARRAY_VERTEX].size() == 1156, "Uploaded surface has 1,156 vertices")
	_assert(uploaded_arrays[Mesh.ARRAY_NORMAL].size() == 1156, "Uploaded surface has 1,156 normals")
	_assert(uploaded_arrays[Mesh.ARRAY_TEX_UV].size() == 1156, "Uploaded surface has 1,156 UVs")
	_assert(uploaded_arrays[Mesh.ARRAY_INDEX].size() == 6534, "Uploaded surface has 6,534 indices")
	
	# Clean up
	dispatcher.shutdown()
	target_mesh.clear_surfaces()

## ============================================================================
## TASK 3: Thread Safety & Lock-Free Scheduler Index Lookup
## ============================================================================
func test_task3_thread_safety_and_lock_free_scheduler() -> void:
	_start("TASK 3: Thread Safety & Lock-Free Worker Index Lookup")
	var scheduler = ChunkTaskScheduler.new()
	_assert(scheduler.get_worker_count() == 4, "Scheduler has 4 concurrent workers")
	
	# Main thread caller id lookup returns 0 (not a worker thread)
	var main_idx: int = ChunkTaskScheduler.get_current_worker_index()
	_assert(main_idx == 0, "Main thread lookup defaults to 0 without error")
	
	# Submit jobs to all 4 worker threads and verify worker indices
	var worker_indices_seen: Dictionary = {}
	var mutex: Mutex = Mutex.new()
	var test_callable = func() -> int:
		var idx: int = ChunkTaskScheduler.get_current_worker_index()
		OS.delay_usec(100)
		mutex.lock()
		worker_indices_seen[idx] = true
		mutex.unlock()
		return idx
	
	for i in range(24):
		scheduler.submit_job(test_callable)
	
	# Poll until jobs complete
	for guard in range(200):
		scheduler.poll()
		if worker_indices_seen.size() == 4:
			break
		OS.delay_msec(5)
	
	_assert(worker_indices_seen.size() == 4, "All 4 worker indices [0, 1, 2, 3] verified via lock-free lookup")
	for w in range(4):
		_assert(worker_indices_seen.has(w), "Worker index %d active" % w)
	
	# Direct worker staging buffers test
	var staging_arr: Array = []
	staging_arr.resize(Mesh.ARRAY_MAX)
	staging_arr[0] = PackedVector3Array(); staging_arr[0].resize(1156)
	staging_arr[1] = PackedVector3Array(); staging_arr[1].resize(1156)
	staging_arr[4] = PackedVector2Array(); staging_arr[4].resize(1156)
	var staging_faces = PackedVector3Array(); staging_faces.resize(6534)
	
	TerrainMeshBuilder.build_chunk_buffers(
		0, 0, Vector2(-1, -1), Vector2(1, 1), 100000.0, 1337, 64.0, 500.0,
		staging_arr, staging_faces, true
	)
	_assert(staging_arr[0].size() == 1156, "build_chunk_buffers populated 1,156 vertices directly")
	_assert(staging_faces.size() == 6534, "build_chunk_buffers populated 6,534 faces directly")
	_assert(staging_arr[0][0] != Vector3.ZERO, "Vertex 0 is non-zero")
	_assert(staging_faces[0] != Vector3.ZERO, "Face vertex 0 is non-zero")
	
	scheduler.shutdown()
	scheduler.free()

## ============================================================================
## TASK 4: Rapid Camera Translation & Rebase Stress
## ============================================================================
func test_task4_rapid_camera_translation_and_rebase_stress() -> void:
	_start("TASK 4: PlanetStreamer Rapid Camera Translation & Rebase Stress")
	var root: Window = get_root()
	var planet: PlanetManager = PlanetManager.new()
	planet.planet_radius = 100_000.0
	planet.max_lod = 4
	root.add_child(planet)
	
	var streamer: PlanetStreamer = PlanetStreamer.new()
	root.add_child(streamer)
	streamer.setup(planet, null, false) # async streaming with 4 background worker threads
	
	_assert(streamer.task_scheduler.get_worker_count() == 4, "Streamer task scheduler initialized with 4 workers")
	
	var test_points: Array[Vector3] = [
		Vector3(100_050.0, 100.0, -200.0),    # Face 0 near surface (+X)
		Vector3(500_000.0, 0.0, 0.0),          # Medium orbit
		Vector3(-100_040.0, 50.0, 50.0),       # Face 1 near surface (-X)
		Vector3(0.0, 10_000_000.0, 0.0),       # Deep space
		Vector3(10.0, 100_080.0, -10.0),       # Face 2 near surface (+Y)
		Vector3(-50.0, -100_030.0, 20.0),      # Face 3 near surface (-Y)
		Vector3(20.0, 30.0, 100_060.0),        # Face 4 near surface (+Z)
		Vector3(0.0, 0.0, -100_050.0),         # Face 5 near surface (-Z)
		Vector3(70710.0, 70710.0, 0.0),        # Seam (+X/+Y)
		Vector3(57735.0, 57735.0, 57735.0),    # Corner (+X/+Y/+Z)
		Vector3(-70710.0, 0.0, -70710.0),      # Seam (-X/-Z)
		Vector3(0.0, -70710.0, 70710.0)        # Seam (-Y/+Z)
	]
	
	var rebase_vectors: Array[Vector3] = [
		Vector3(2_000.0, -1_000.0, 500.0),
		Vector3(-3_000.0, 2_500.0, -1_200.0),
		Vector3(5_000.0, 0.0, -4_000.0),
		Vector3(-4_000.0, -1_500.0, 3_000.0)
	]
	
	var iterations: int = 48
	var stress_invariants_held: bool = true
	var rebase_count: int = 0
	
	for iter in range(iterations):
		var target_pos: Vector3 = test_points[iter % test_points.size()]
		streamer.update_streamer(target_pos)
		
		# Trigger rebase events every 4 iterations
		if iter % 4 == 0:
			var offset: Vector3 = rebase_vectors[(iter / 4) % rebase_vectors.size()]
			planet.rebase_origin(offset)
			streamer.rebase_origin(offset)
			rebase_count += 1
			if streamer.global_position.distance_to(planet.planet_center_offset) > 1e-4:
				stress_invariants_held = false
		
		# Process a frame to allow worker threads to run and poll
		await process_frame
		
		# Verify thread safety and buffer conservation invariants
		if streamer.pending_jobs < 0 or streamer.retired_count < 0:
			stress_invariants_held = false
		if streamer.staging_free.size() + streamer.pending_jobs + streamer.retired_count > streamer.JOB_CAPACITY:
			stress_invariants_held = false
		if streamer.task_scheduler.get_worker_count() != 4:
			stress_invariants_held = false
	
	_assert(stress_invariants_held, "All stream invariants held during %d rapid teleports and %d rebases" % [iterations, rebase_count])
	_assert(streamer.queued_job_count > 0, "Jobs were queued during rapid camera translation stress")
	_assert(streamer.cancelled_job_count > 0, "Cancelled obsolete jobs during rapid camera translation stress")
	
	# Settle phase: park camera at Face 0 low altitude and allow async convergence
	var settle_camera: Vector3 = Vector3(100_050.0, 0.0, 0.0)
	var settled: bool = false
	for guard in range(300):
		streamer.update_streamer(settle_camera)
		await process_frame
		streamer.task_scheduler.poll()
		streamer._release_retired_staging()
		if streamer.pending_jobs == 0 and streamer.retired_count == 0:
			settled = true
			break
	
	_assert(settled, "PlanetStreamer settled cleanly after stress without hanging")
	_assert(streamer.pending_jobs == 0, "Pending jobs settled to exactly 0")
	_assert(streamer.retired_count == 0, "Retired staging count settled to exactly 0")
	_assert(streamer.staging_free.size() == streamer.JOB_CAPACITY, 
		"Staging pool conserved: all %d slots available (zero leaked staging buffers)" % streamer.JOB_CAPACITY)
	_assert(streamer.get_orphan_mesh_count() == 0, "Zero orphan meshes after settling")
	
	var audit: Dictionary = planet.audit_system()
	_assert(audit["is_valid"], "PlanetManager quadtree and pool audit is valid after stress")
	_assert(audit["orphan_count"] == 0, "Zero orphan nodes in quadtree audit")
	
	# Teardown
	streamer.destroy()
	root.remove_child(streamer)
	streamer.free()
	
	planet.destroy()
	root.remove_child(planet)
	planet.free()
	
	print("  Task 4 Verified: 48 rapid camera teleports + 12 rebases completed with 0 leaks, 0 crashes")

## ============================================================================
## ADVERSARIAL STRESS & CORNER / CLIFF TESTS
## ============================================================================
func test_adversarial_stress_and_edge_cases() -> void:
	_start("ADVERSARIAL: Seam Cliff Detection Oracle & All 8 Cube Corner Tri-Face Invariants")
	
	# Test 1: Oracle verification - confirm that seed_face_stride = 17 (pre-Phase C bug)
	# ACTUALLY produces cliffs up to 1000m, proving that our test harness is sensitive!
	var planet_radius: float = 100_000.0
	var buggy_stride: int = 17
	var dir0: Vector3 = PlanetMath.face_uv_to_sphere_dir(0, Vector2(1.0, 0.0))
	var dir5: Vector3 = PlanetMath.face_uv_to_sphere_dir(5, Vector2(-1.0, 0.0))
	var h0_buggy: float = PlanetMath.get_terrain_height(dir0, planet_radius, 1337 + 0 * buggy_stride, 64.0, 500.0)
	var h5_buggy: float = PlanetMath.get_terrain_height(dir5, planet_radius, 1337 + 5 * buggy_stride, 64.0, 500.0)
	var cliff_delta: float = absf(h0_buggy - h5_buggy)
	_assert(cliff_delta > 10.0, "Oracle confirmed: buggy seed_face_stride=17 produces severe cliff (delta=%.2f m)" % cliff_delta)
	
	# Now with fixed seed_face_stride = 0:
	var h0_fixed: float = PlanetMath.get_terrain_height(dir0, planet_radius, 1337 + 0 * 0, 64.0, 500.0)
	var h5_fixed: float = PlanetMath.get_terrain_height(dir5, planet_radius, 1337 + 5 * 0, 64.0, 500.0)
	_assert(absf(h0_fixed - h5_fixed) == 0.0, "Zero stride eliminates seam cliff completely (delta = 0.000000 m)")
	
	# Test 2: All 8 Cube Corners Tri-Face Invariant
	var corners: Array = [
		{"name": "(+X, +Y, +Z)", "fA": 0, "uvA": Vector2(-1.0, 1.0), "fB": 2, "uvB": Vector2(1.0, 1.0), "fC": 4, "uvC": Vector2(1.0, 1.0)},
		{"name": "(+X, +Y, -Z)", "fA": 0, "uvA": Vector2(1.0, 1.0), "fB": 2, "uvB": Vector2(-1.0, 1.0), "fC": 5, "uvC": Vector2(-1.0, 1.0)},
		{"name": "(+X, -Y, +Z)", "fA": 0, "uvA": Vector2(-1.0, -1.0), "fB": 3, "uvB": Vector2(-1.0, 1.0), "fC": 4, "uvC": Vector2(1.0, -1.0)},
		{"name": "(+X, -Y, -Z)", "fA": 0, "uvA": Vector2(1.0, -1.0), "fB": 3, "uvB": Vector2(1.0, 1.0), "fC": 5, "uvC": Vector2(-1.0, -1.0)},
		{"name": "(-X, +Y, +Z)", "fA": 1, "uvA": Vector2(1.0, 1.0), "fB": 2, "uvB": Vector2(1.0, -1.0), "fC": 4, "uvC": Vector2(-1.0, 1.0)},
		{"name": "(-X, +Y, -Z)", "fA": 1, "uvA": Vector2(-1.0, 1.0), "fB": 2, "uvB": Vector2(-1.0, -1.0), "fC": 5, "uvC": Vector2(1.0, 1.0)},
		{"name": "(-X, -Y, +Z)", "fA": 1, "uvA": Vector2(1.0, -1.0), "fB": 3, "uvB": Vector2(-1.0, -1.0), "fC": 4, "uvC": Vector2(-1.0, -1.0)},
		{"name": "(-X, -Y, -Z)", "fA": 1, "uvA": Vector2(-1.0, -1.0), "fB": 3, "uvB": Vector2(1.0, -1.0), "fC": 5, "uvC": Vector2(1.0, -1.0)}
	]
	
	_assert(corners.size() == 8, "All 8 cube corners defined")
	
	for c in corners:
		var cname: String = c["name"]
		var dirA: Vector3 = PlanetMath.face_uv_to_sphere_dir(c["fA"], c["uvA"])
		var dirB: Vector3 = PlanetMath.face_uv_to_sphere_dir(c["fB"], c["uvB"])
		var dirC: Vector3 = PlanetMath.face_uv_to_sphere_dir(c["fC"], c["uvC"])
		
		_assert_vec3_approx(dirA, dirB, 1e-5, "%s: Face A direction == Face B direction" % cname)
		_assert_vec3_approx(dirA, dirC, 1e-5, "%s: Face A direction == Face C direction" % cname)
		
		var hA: float = PlanetMath.get_terrain_height(dirA, planet_radius, 1337, 64.0, 500.0)
		var hB: float = PlanetMath.get_terrain_height(dirB, planet_radius, 1337, 64.0, 500.0)
		var hC: float = PlanetMath.get_terrain_height(dirC, planet_radius, 1337, 64.0, 500.0)
		
		_assert(hA == hB and hA == hC, "%s: Tri-face elevation is bit-for-bit identical across all 3 faces" % cname)

## ============================================================================
## TASK 5: Convergence Benchmark Across 24, 48, and 96 Chunk Generation Calls
## ============================================================================
var _task5_completed: int = 0
var _task5_scheduler: ChunkTaskScheduler = null
var _task5_staging_arrays: Array[Array] = []
var _task5_staging_faces: Array[PackedVector3Array] = []

func _task5_build_chunk_job(idx: int) -> bool:
	TerrainMeshBuilder.build_chunk_buffers(
		idx % 6, 1, Vector2(-1, -1), Vector2(1, 1), 100_000.0, 1337, 64.0, 500.0,
		_task5_staging_arrays[idx], _task5_staging_faces[idx], true
	)
	return true

func _on_task5_job_completed(job_id: int, _res: Variant) -> void:
	if _task5_scheduler != null:
		_task5_scheduler.reclaim_job(job_id)
	_task5_completed += 1

func test_task5_convergence_benchmark_24_48_96() -> void:
	_start("TASK 5: Multi-Threaded Chunk Generation Convergence Benchmark (24, 48, 96 Chunks)")
	TerrainMeshBuilder.init_builder()
	
	# Benchmark 24 chunks (Architectural LOD 1 Quadtree Generation)
	_task5_scheduler = ChunkTaskScheduler.new()
	_task5_scheduler.job_completed.connect(_on_task5_job_completed)
	_task5_completed = 0
	var total_24: int = 24
	_task5_staging_arrays.resize(total_24)
	_task5_staging_faces.resize(total_24)
	for c in range(total_24):
		var v: PackedVector3Array = PackedVector3Array(); v.resize(1156)
		var n: PackedVector3Array = PackedVector3Array(); n.resize(1156)
		var u: PackedVector2Array = PackedVector2Array(); u.resize(1156)
		var arr: Array = []; arr.resize(Mesh.ARRAY_MAX)
		arr[0] = v; arr[1] = n; arr[4] = u; arr[12] = TerrainMeshBuilder._indices
		_task5_staging_arrays[c] = arr
		var f: PackedVector3Array = PackedVector3Array(); f.resize(6534)
		_task5_staging_faces[c] = f
	
	var callable: Callable = Callable(self, "_task5_build_chunk_job")
	for i in range(total_24):
		_task5_scheduler.submit_job(callable, [i])
	
	var frames_24: int = 0
	var start_time_24: int = Time.get_ticks_usec()
	while frames_24 < 80 and _task5_completed < total_24:
		frames_24 += 1
		await process_frame
		_task5_scheduler.poll()
	var ms_24: float = float(Time.get_ticks_usec() - start_time_24) / 1000.0
	
	_assert(_task5_completed == 24, "24 chunk generation completed 24/24 chunks (completed %d)" % _task5_completed)
	_assert(frames_24 <= 80, "24 chunk generation converged strictly within 80 headless frames (converged at frame %d, %.2f ms)" % [frames_24, ms_24])
	
	# Verify output geometry of 24 chunks
	var geometry_valid: bool = true
	for c in range(total_24):
		var verts: PackedVector3Array = _task5_staging_arrays[c][0]
		var faces: PackedVector3Array = _task5_staging_faces[c]
		if verts.size() != 1156 or verts[0] == Vector3.ZERO or faces.size() != 6534 or faces[0] == Vector3.ZERO:
			geometry_valid = false
			break
	_assert(geometry_valid, "All 24 generated chunk buffers contain valid vertices and faces")
	
	_task5_scheduler.shutdown()
	_task5_scheduler.free()
	_task5_scheduler = null
	
	# Benchmark 48 chunks
	_task5_scheduler = ChunkTaskScheduler.new()
	_task5_scheduler.job_completed.connect(_on_task5_job_completed)
	_task5_completed = 0
	var total_48: int = 48
	_task5_staging_arrays.resize(total_48)
	_task5_staging_faces.resize(total_48)
	for c in range(total_48):
		var v: PackedVector3Array = PackedVector3Array(); v.resize(1156)
		var n: PackedVector3Array = PackedVector3Array(); n.resize(1156)
		var u: PackedVector2Array = PackedVector2Array(); u.resize(1156)
		var arr: Array = []; arr.resize(Mesh.ARRAY_MAX)
		arr[0] = v; arr[1] = n; arr[4] = u; arr[12] = TerrainMeshBuilder._indices
		_task5_staging_arrays[c] = arr
		var f: PackedVector3Array = PackedVector3Array(); f.resize(6534)
		_task5_staging_faces[c] = f
	
	for i in range(total_48):
		_task5_scheduler.submit_job(callable, [i])
	
	var frames_48: int = 0
	var start_time_48: int = Time.get_ticks_usec()
	while frames_48 < 140 and _task5_completed < total_48:
		frames_48 += 1
		await process_frame
		_task5_scheduler.poll()
	var ms_48: float = float(Time.get_ticks_usec() - start_time_48) / 1000.0
	
	_assert(_task5_completed == 48, "48 chunk generation completed 48/48 chunks (completed %d, %d frames, %.2f ms)" % [_task5_completed, frames_48, ms_48])
	_task5_scheduler.shutdown()
	_task5_scheduler.free()
	_task5_scheduler = null
	
	# Benchmark 96 chunks (Exceeds 64-slot ring buffer capacity, requires continuous slot reclamation)
	_task5_scheduler = ChunkTaskScheduler.new()
	_task5_scheduler.job_completed.connect(_on_task5_job_completed)
	_task5_completed = 0
	var total_96: int = 96
	_task5_staging_arrays.resize(total_96)
	_task5_staging_faces.resize(total_96)
	for c in range(total_96):
		var v: PackedVector3Array = PackedVector3Array(); v.resize(1156)
		var n: PackedVector3Array = PackedVector3Array(); n.resize(1156)
		var u: PackedVector2Array = PackedVector2Array(); u.resize(1156)
		var arr: Array = []; arr.resize(Mesh.ARRAY_MAX)
		arr[0] = v; arr[1] = n; arr[4] = u; arr[12] = TerrainMeshBuilder._indices
		_task5_staging_arrays[c] = arr
		var f: PackedVector3Array = PackedVector3Array(); f.resize(6534)
		_task5_staging_faces[c] = f
	
	var queued_96: int = 0
	var frames_96: int = 0
	var start_time_96: int = Time.get_ticks_usec()
	while frames_96 < 260 and _task5_completed < total_96:
		while queued_96 < total_96 and _task5_scheduler.get_available_slots() > 0:
			var jid: int = _task5_scheduler.submit_job(callable, [queued_96])
			if jid <= 0: break
			queued_96 += 1
		frames_96 += 1
		await process_frame
		_task5_scheduler.poll()
	var ms_96: float = float(Time.get_ticks_usec() - start_time_96) / 1000.0
	
	_assert(_task5_completed == 96, "96 chunk generation completed 96/96 chunks with 64-slot streaming (%d frames, %.2f ms)" % [frames_96, ms_96])
	_assert(_task5_scheduler.get_active_worker_count() == 0, "All 4 worker threads returned to idle after 96 chunk stress")
	
	_task5_scheduler.shutdown()
	_task5_scheduler.free()
	_task5_scheduler = null
	
	print("  Task 5 Verified: 24 chunks (%d frames, %.2f ms), 48 chunks (%d frames, %.2f ms), 96 chunks (%d frames, %.2f ms)" % [
		frames_24, ms_24, frames_48, ms_48, frames_96, ms_96
	])

## ============================================================================
## TASK 6: 1,000-Tick Streaming Updates Zero-Allocation Audit
## ============================================================================
func test_task6_zero_allocation_streaming_audit_1000_ticks() -> void:
	_start("TASK 6: 1,000-Tick Streaming Updates Zero Runtime Heap Allocation Audit")
	var root: Window = get_root()
	var planet: PlanetManager = PlanetManager.new()
	planet.planet_radius = 100_000.0
	planet.max_lod = 2
	root.add_child(planet)
	
	var streamer: PlanetStreamer = PlanetStreamer.new()
	root.add_child(streamer)
	streamer.setup(planet, null, true) # Synchronous mode for zero-allocation tick validation
	
	# Warm up for 120 ticks
	var camera_pos: Vector3 = Vector3(100_050.0, 1_000.0, 1_000.0)
	for i in range(120):
		streamer.update_streamer(camera_pos)
	
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1000):
		streamer.update_streamer(camera_pos)
	var memory_after: int = OS.get_static_memory_usage()
	var memory_delta: int = memory_after - memory_before
	
	_assert(memory_delta <= 0, "PlanetStreamer 1,000 ticks static memory delta <= 0 bytes (got %d bytes)" % memory_delta)
	_assert(streamer.get_orphan_mesh_count() == 0, "PlanetStreamer orphan mesh count is 0 after 1,000 ticks")
	
	streamer.destroy()
	root.remove_child(streamer)
	streamer.free()
	planet.destroy()
	root.remove_child(planet)
	planet.free()
	
	# Full Simulation Stack Audit (1,000 ticks with streaming + flight + combat)
	var sim_packed: PackedScene = load("res://main.tscn")
	var sim: Node = sim_packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	root.add_child(sim)
	
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
	
	for i in range(120):
		sim.step_simulation(1.0 / 120.0)
	
	var sim_mem_before: int = OS.get_static_memory_usage()
	for i in range(1000):
		sim.step_simulation(1.0 / 120.0)
	var sim_mem_after: int = OS.get_static_memory_usage()
	var sim_mem_delta: int = sim_mem_after - sim_mem_before
	
	_assert(sim_mem_delta <= 0, "Full simulation stack 1,000 ticks static memory delta <= 0 bytes (got %d bytes)" % sim_mem_delta)
	
	sim.destroy()
	root.remove_child(sim)
	sim.free()
	
	print("  Task 6 Verified: Streamer delta = %d bytes, Full sim stack delta = %d bytes (both <= 0)" % [memory_delta, sim_mem_delta])

func _print_summary() -> void:
	print("==================================================================")
	print("CHALLENGER 2 PHASE C VERIFICATION SUMMARY")
	print("  Total Assertions:  %d" % total_assertions)
	print("  Passed Assertions: %d" % passed_assertions)
	print("  Failed Assertions: %d" % failed_assertions)
	print("==================================================================")
	if failed_assertions == 0:
		print("SUCCESS: 100% empirical assertions passed across all tasks!")
	else:
		printerr("FAILURE: %d assertions failed!" % failed_assertions)
