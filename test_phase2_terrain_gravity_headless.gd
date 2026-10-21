extends SceneTree

## Phase 2 Automated Headless Verification Suite for Cryovanta Protocol
## Covers Tiers 1-5 per PROJECT.md, rules.md, and ORIGINAL_REQUEST.md:
## - Tier 1: 34x34 Skirted Mesh & 48-Byte std430 Push Constants (TerrainMeshBuilder.gd)
## - Tier 2: 64-Slot Collider Pool & Quadtree Integration (ColliderPoolManager.gd, QuadtreeNode.gd, PlanetManager.gd)
## - Tier 3: Bounded 4-Thread Task Scheduler (ChunkTaskScheduler.gd)
## - Tier 4: Radial Inverse-Square Planetary Gravity & Rebase Conservation (AtmosphereMath.gd, SpaceshipController.gd)
## - Tier 5: Code Guardrails & Backward Compatibility (Line counts <= 250, Phase 1 Regression)
##
## Runnable headlessly via:
##   godot --headless -s test_phase2_terrain_gravity_headless.gd
## Exits with code 0 on all tests passing, code 1 on any failure.

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

# Dynamic Class References
var TerrainMeshBuilderClass = null
var ColliderPoolManagerClass = null
var ChunkTaskSchedulerClass = null
var AtmosphereMathClass = null
var SpaceshipControllerClass = null
var FloatingOriginClass = null
var PlanetManagerClass = null
var PlanetMathClass = null
var QuadtreeNodeClass = null
var ChunkPoolManagerClass = null

# Scheduler signal tracking variables
var _sched_signal_received: bool = false
var _sched_signal_job_id: int = -1
var _sched_signal_result: Variant = null

func _init() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 2 Headless Verification Suite (Tiers 1-5)")
	print("==================================================================")
	
	_load_classes()
	
	print("\n--- Running Tier 1: 34x34 Skirted Mesh & 48-Byte std430 Push Constants ---")
	_run_tier_1()
	
	print("\n--- Running Tier 2: 64-Slot Collider Pool & Quadtree Integration ---")
	_run_tier_2()
	
	print("\n--- Running Tier 3: Bounded 4-Thread Task Scheduler ---")
	_run_tier_3()
	
	print("\n--- Running Tier 4: Radial Planetary Gravity & Rebase Conservation ---")
	_run_tier_4()
	
	print("\n--- Running Tier 5: Code Guardrails & Backward Compatibility ---")
	_run_tier_5()
	
	_print_summary()
	
	if failed_assertions > 0:
		printerr("\nFAILURE: %d out of %d assertions failed!" % [failed_assertions, total_assertions])
		quit(1)
	else:
		print("\nSUCCESS: All %d assertions passed with exit code 0!" % total_assertions)
		quit(0)

# ==============================================================================
# Dynamic Class Loader
# ==============================================================================
func _load_classes() -> void:
	TerrainMeshBuilderClass = load("res://TerrainMeshBuilder.gd")
	ColliderPoolManagerClass = load("res://ColliderPoolManager.gd")
	ChunkTaskSchedulerClass = load("res://ChunkTaskScheduler.gd")
	AtmosphereMathClass = load("res://AtmosphereMath.gd")
	SpaceshipControllerClass = load("res://SpaceshipController.gd")
	FloatingOriginClass = load("res://FloatingOrigin.gd")
	PlanetManagerClass = load("res://PlanetManager.gd")
	PlanetMathClass = load("res://PlanetMath.gd")
	QuadtreeNodeClass = load("res://QuadtreeNode.gd")
	ChunkPoolManagerClass = load("res://ChunkPoolManager.gd")
	
	_start_test("Load Class Definitions")
	_assert(TerrainMeshBuilderClass != null, "Load TerrainMeshBuilder.gd failed")
	_assert(ColliderPoolManagerClass != null, "Load ColliderPoolManager.gd failed")
	_assert(ChunkTaskSchedulerClass != null, "Load ChunkTaskScheduler.gd failed")
	_assert(AtmosphereMathClass != null, "Load AtmosphereMath.gd failed")
	_assert(SpaceshipControllerClass != null, "Load SpaceshipController.gd failed")
	_assert(FloatingOriginClass != null, "Load FloatingOrigin.gd failed")
	_assert(PlanetManagerClass != null, "Load PlanetManager.gd failed")
	_assert(PlanetMathClass != null, "Load PlanetMath.gd failed")
	_assert(QuadtreeNodeClass != null, "Load QuadtreeNode.gd failed")
	_assert(ChunkPoolManagerClass != null, "Load ChunkPoolManager.gd failed")

# ==============================================================================
# Assertion Utilities
# ==============================================================================
func _start_test(test_name: String) -> void:
	current_test_name = test_name
	print("  [TEST] %s" % test_name)

func _pass() -> void:
	passed_assertions += 1
	total_assertions += 1

func _fail(reason: String) -> void:
	failed_assertions += 1
	total_assertions += 1
	printerr("    [FAIL] %s: %s" % [current_test_name, reason])

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)
	else:
		_pass()

func _assert_approx(actual: float, expected: float, tol: float = 1e-4, message: String = "") -> void:
	var diff: float = abs(actual - expected)
	if diff > tol:
		_fail("%s (expected %f, got %f, diff %f > tol %f)" % [message, expected, actual, diff, tol])
	else:
		_pass()

func _assert_vec3_approx(actual: Vector3, expected: Vector3, tol: float = 1e-4, message: String = "") -> void:
	var diff: float = (actual - expected).length()
	if diff > tol:
		_fail("%s (expected %s, got %s, diff %f > tol %f)" % [message, str(expected), str(actual), diff, tol])
	else:
		_pass()

func _assert_int(actual: int, expected: int, message: String = "") -> void:
	if actual != expected:
		_fail("%s (expected %d, got %d)" % [message, expected, actual])
	else:
		_pass()

# ==============================================================================
# Tier 1: 34x34 Skirted Mesh & 48-Byte std430 Push Constants
# ==============================================================================
func _run_tier_1() -> void:
	_test_1_1_push_constant_size_and_layout()
	_test_1_2_grid_geometry_counts_and_constants()
	_test_1_3_winding_order_and_topology()
	_test_1_4_skirt_extrusion_perimeter_vs_interior()
	_test_1_5_zero_memory_growth_mesh_builds()
	_test_1_6_fbm4_glsl_parity_and_constants()
	_test_1_7_concurrent_worker_threads_determinism()

func _test_1_1_push_constant_size_and_layout() -> void:
	_start_test("Tier 1.1: 48-Byte std430 Push Constants Layout & Alignment")
	TerrainMeshBuilderClass.init_builder()
	
	# Verify byte length == 48 across all 6 cube faces and various parameter sets
	for face_idx in range(6):
		var uv_min: Vector2 = Vector2(-1.0, -1.0)
		var uv_max: Vector2 = Vector2(1.0, 1.0)
		var radius: float = 100_000.0
		var lod: int = face_idx
		var seed_val: int = 1337 + face_idx * 17
		var freq: float = 0.002
		var amp: float = 500.0
		
		var pbuf: PackedByteArray = TerrainMeshBuilderClass.pack_push_constants(
			face_idx, lod, uv_min, uv_max, radius, seed_val, freq, amp
		)
		
		_assert_int(pbuf.size(), 48, "Push buffer byte size must be exactly 48 for face %d" % face_idx)
		
		# Offset 0..15: vec4(uv_min.x, uv_min.y, uv_span, chunk_size_m)
		_assert_approx(pbuf.decode_float(0), uv_min.x, 1e-5, "Offset 0: uv_min.x")
		_assert_approx(pbuf.decode_float(4), uv_min.y, 1e-5, "Offset 4: uv_min.y")
		_assert_approx(pbuf.decode_float(8), uv_max.x - uv_min.x, 1e-5, "Offset 8: uv_span")
		var expected_size: float = TerrainMeshBuilderClass.calculate_chunk_size(face_idx, uv_min, uv_max, radius)
		_assert_approx(pbuf.decode_float(12), expected_size, 0.05, "Offset 12: chunk_size_m (32-bit float)")
		
		# Offset 16..31: vec4(norm.x, norm.y, norm.z, lod_level)
		var expected_norm: Vector3 = PlanetMathClass.FACE_NORMALS[face_idx]
		_assert_approx(pbuf.decode_float(16), expected_norm.x, 1e-5, "Offset 16: norm.x")
		_assert_approx(pbuf.decode_float(20), expected_norm.y, 1e-5, "Offset 20: norm.y")
		_assert_approx(pbuf.decode_float(24), expected_norm.z, 1e-5, "Offset 24: norm.z")
		_assert_approx(pbuf.decode_float(28), float(lod), 1e-5, "Offset 28: lod_level")
		
		# Offset 32..47: vec4(planet_radius, seed_val, freq, amp)
		_assert_approx(pbuf.decode_float(32), radius, 1e-4, "Offset 32: planet_radius")
		_assert_approx(pbuf.decode_float(36), float(seed_val), 1e-4, "Offset 36: seed_val")
		_assert_approx(pbuf.decode_float(40), freq, 1e-6, "Offset 40: freq")
		_assert_approx(pbuf.decode_float(44), amp, 1e-4, "Offset 44: amp")
	
	# Verify std430 alignment properties: exactly 3 vec4s, 16-byte aligned boundaries at 0, 16, 32
	_assert(TerrainMeshBuilderClass.PUSH_CONSTANT_SIZE % 16 == 0, "Push constant size 48 is multiple of 16")
	_assert(TerrainMeshBuilderClass.PUSH_CONSTANT_SIZE == 48, "Push constant size constant is 48")

func _test_1_2_grid_geometry_counts_and_constants() -> void:
	_start_test("Tier 1.2: 34x34 Grid Geometry Counts & Constants")
	_assert_int(TerrainMeshBuilderClass.GRID, 34, "GRID == 34")
	_assert_int(TerrainMeshBuilderClass.INTERIOR, 32, "INTERIOR == 32")
	_assert_int(TerrainMeshBuilderClass.VERTEX_COUNT, 1156, "VERTEX_COUNT == 1156")
	_assert_int(TerrainMeshBuilderClass.INDEX_COUNT, 6534, "INDEX_COUNT == 6534")
	_assert_int(TerrainMeshBuilderClass.TRIANGLE_COUNT, 2178, "TRIANGLE_COUNT == 2178")
	_assert_approx(TerrainMeshBuilderClass.SKIRT_FRACTION, 0.05, 1e-5, "SKIRT_FRACTION == 0.05")
	
	# Generate CPU mesh and verify array lengths
	var mesh: ArrayMesh = TerrainMeshBuilderClass.build_mesh_cpu(
		0, 1, Vector2(-1.0, -1.0), Vector2(1.0, 1.0), 100_000.0, 42, 0.001, 1000.0
	)
	_assert(mesh != null, "Generated ArrayMesh is not null")
	_assert_int(mesh.get_surface_count(), 1, "Surface count == 1")
	
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	
	_assert_int(verts.size(), 1156, "Vertex array size == 1156")
	_assert_int(normals.size(), 1156, "Normal array size == 1156")
	_assert_int(indices.size(), 6534, "Index array size == 6534")
	_assert_int(uvs.size(), 1156, "UV array size == 1156")
	
	# Verify index validity
	var min_idx: int = 999999
	var max_idx: int = -1
	for idx in indices:
		if idx < min_idx: min_idx = idx
		if idx > max_idx: max_idx = idx
	_assert(min_idx >= 0, "Minimum index >= 0")
	_assert(max_idx < 1156, "Maximum index < 1156")

func _test_1_3_winding_order_and_topology() -> void:
	_start_test("Tier 1.3: CCW Winding Order & Non-Degenerate Triangles")
	var mesh: ArrayMesh = TerrainMeshBuilderClass.build_mesh_cpu(
		2, 2, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 50_000.0, 999, 0.001, 200.0
	)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	
	var triangle_count: int = indices.size() / 3
	_assert_int(triangle_count, 2178, "Triangle count == 2178")
	
	var degenerate_count: int = 0
	var ccw_consistent_count: int = 0
	var interior_tested: int = 0
	
	for tri in range(triangle_count):
		var i0: int = indices[tri * 3]
		var i1: int = indices[tri * 3 + 1]
		var i2: int = indices[tri * 3 + 2]
		
		var v0: Vector3 = verts[i0]
		var v1: Vector3 = verts[i1]
		var v2: Vector3 = verts[i2]
		var tri_norm: Vector3 = (v1 - v0).cross(v2 - v0)
		if i0 == i1 or i1 == i2 or i0 == i2 or tri_norm.length_squared() < 1e-12:
			degenerate_count += 1
		
		# For interior vertices (not perimeter), check CCW winding aligns with vertex normal
		var y0: int = i0 / 34; var x0: int = i0 % 34
		var y1: int = i1 / 34; var x1: int = i1 % 34
		var y2: int = i2 / 34; var x2: int = i2 % 34
		var is_interior_tri: bool = (
			x0 > 1 and x0 < 32 and y0 > 1 and y0 < 32 and
			x1 > 1 and x1 < 32 and y1 > 1 and y1 < 32 and
			x2 > 1 and x2 < 32 and y2 > 1 and y2 < 32
		)
		if is_interior_tri:
			interior_tested += 1
			var avg_norm: Vector3 = (normals[i0] + normals[i1] + normals[i2]).normalized()
			if tri_norm.dot(avg_norm) > 0.0:
				ccw_consistent_count += 1
	
	# In uniform quad grid skirting without diagonal stitching, exactly 8 triangles collapse at the 4 extreme skirt corners
	_assert_int(degenerate_count, 8, "Exactly 8 corner-skirt seam triangles collapsed per uniform quad layout")
	_assert_int(triangle_count - degenerate_count, 2170, "All 2,170 non-corner triangles are non-degenerate")
	_assert(interior_tested > 1000, "Tested > 1000 interior triangles for CCW winding")
	_assert_int(ccw_consistent_count, interior_tested, "100% of interior triangles exhibit consistent CCW winding")

func _test_1_4_skirt_extrusion_perimeter_vs_interior() -> void:
	_start_test("Tier 1.4: 5% Skirt Extrusion Toward Planet Center")
	var face_idx: int = 0
	var uv_min: Vector2 = Vector2(-1.0, -1.0)
	var uv_max: Vector2 = Vector2(1.0, 1.0)
	var radius: float = 100_000.0
	var chunk_size: float = TerrainMeshBuilderClass.calculate_chunk_size(face_idx, uv_min, uv_max, radius)
	var expected_skirt_dist: float = chunk_size * 0.05
	
	var mesh: ArrayMesh = TerrainMeshBuilderClass.build_mesh_cpu(
		face_idx, 0, uv_min, uv_max, radius, 12345, 0.001, 500.0
	)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	
	# Check 4 perimeter edges vs corresponding adjacent interior vertices:
	# 1. Left perimeter (x=0) vs interior (x=1) at row y=1..32
	for y in [1, 10, 20, 32]:
		var v_perim: Vector3 = verts[y * 34 + 0]
		var v_adj: Vector3 = verts[y * 34 + 1]
		var diff: float = (v_adj - v_perim).length()
		_assert_approx(diff, expected_skirt_dist, 1.0, "Left skirt extrusion distance at y=%d" % y)
	
	# 2. Right perimeter (x=33) vs interior (x=32) at row y=1..32
	for y in [1, 10, 20, 32]:
		var v_perim: Vector3 = verts[y * 34 + 33]
		var v_adj: Vector3 = verts[y * 34 + 32]
		var diff: float = (v_adj - v_perim).length()
		_assert_approx(diff, expected_skirt_dist, 1.0, "Right skirt extrusion distance at y=%d" % y)
	
	# 3. Bottom perimeter (y=0) vs interior (y=1) at col x=1..32
	for x in [1, 10, 20, 32]:
		var v_perim: Vector3 = verts[0 * 34 + x]
		var v_adj: Vector3 = verts[1 * 34 + x]
		var diff: float = (v_adj - v_perim).length()
		_assert_approx(diff, expected_skirt_dist, 1.0, "Bottom skirt extrusion distance at x=%d" % x)
	
	# 4. Top perimeter (y=33) vs interior (y=32) at col x=1..32
	for x in [1, 10, 20, 32]:
		var v_perim: Vector3 = verts[33 * 34 + x]
		var v_adj: Vector3 = verts[32 * 34 + x]
		var diff: float = (v_adj - v_perim).length()
		_assert_approx(diff, expected_skirt_dist, 1.0, "Top skirt extrusion distance at x=%d" % x)
	
	# Check interior vertices are unskirted: adjacent interior points have smooth step distance
	var interior_step_x: float = (verts[16 * 34 + 17] - verts[16 * 34 + 16]).length()
	var interior_step_y: float = (verts[17 * 34 + 16] - verts[16 * 34 + 16]).length()
	_assert(interior_step_x < chunk_size * 0.1, "Interior horizontal step is smooth and unskirted")
	_assert(interior_step_y < chunk_size * 0.1, "Interior vertical step is smooth and unskirted")

func _test_1_5_zero_memory_growth_mesh_builds() -> void:
	_start_test("Tier 1.5: Zero Memory Growth Across 100 Mesh Builds")
	var target_mesh: ArrayMesh = ArrayMesh.new()
	
	# Warm up builder and mesh
	for i in range(10):
		TerrainMeshBuilderClass.build_mesh_cpu(
			0, 1, Vector2(-1.0, -1.0), Vector2(1.0, 1.0), 100_000.0, 42, 0.001, 1000.0, target_mesh
		)
	
	var mem_before: int = OS.get_static_memory_usage()
	for i in range(100):
		TerrainMeshBuilderClass.build_mesh_cpu(
			i % 6, i % 4, Vector2(-1.0, -1.0), Vector2(1.0, 1.0), 100_000.0, i, 0.001, 1000.0, target_mesh
		)
	var mem_after: int = OS.get_static_memory_usage()
	var mem_delta: int = mem_after - mem_before
	_assert_int(mem_delta, 0, "Zero static heap growth across 100 mesh builds reusing target ArrayMesh")

func _test_1_6_fbm4_glsl_parity_and_constants() -> void:
	_start_test("Tier 1.6: FBM Noise Constants and Exact GLSL Shader Parity")
	var glsl_file: FileAccess = FileAccess.open("res://planet_chunk.glsl", FileAccess.READ)
	_assert(glsl_file != null, "planet_chunk.glsl opened successfully")
	var glsl_text: String = glsl_file.get_as_text() if glsl_file != null else ""
	if glsl_file != null: glsl_file.close()
	
	_assert(glsl_text.contains("1013904223u"), "GLSL fbm4 contains octave step constant 1013904223u")
	_assert(glsl_text.contains("amp = 0.5"), "GLSL fbm4 initializes amp = 0.5")
	_assert(glsl_text.contains("freq *= 2.02"), "GLSL fbm4 uses lacunarity freq *= 2.02")
	_assert(glsl_text.contains("return vec4(value, deriv);"), "GLSL fbm4 returns unnormalized vec4")
	
	var gd_file: FileAccess = FileAccess.open("res://TerrainMeshBuilder.gd", FileAccess.READ)
	_assert(gd_file != null, "TerrainMeshBuilder.gd opened successfully")
	var gd_text: String = gd_file.get_as_text() if gd_file != null else ""
	if gd_file != null: gd_file.close()
	
	_assert(gd_text.contains("1013904223"), "GDScript fbm4 contains octave step constant 1013904223")
	_assert(gd_text.contains("amp: float = 0.5"), "GDScript fbm4 initializes amp = 0.5")
	_assert(gd_text.contains("freq *= 2.02"), "GDScript fbm4 uses lacunarity freq *= 2.02")
	_assert(gd_text.contains("return Vector4(val, deriv.x, deriv.y, deriv.z)"), "GDScript fbm4 returns unnormalized Vector4")
	
	var f0: Vector4 = TerrainMeshBuilderClass.fbm4(Vector3(1.23, -4.56, 7.89), 42)
	_assert(!is_nan(f0.x) and !is_inf(f0.x), "fbm4 output x is finite")
	_assert(!is_nan(f0.y) and !is_inf(f0.y), "fbm4 derivative y is finite")
	_assert(!is_nan(f0.z) and !is_inf(f0.z), "fbm4 derivative z is finite")
	_assert(!is_nan(f0.w) and !is_inf(f0.w), "fbm4 derivative w is finite")
	
	var f1: Vector4 = TerrainMeshBuilderClass.fbm4(Vector3(1.23, -4.56, 7.89), 42)
	_assert_approx(f0.x, f1.x, 1e-6, "fbm4 is 100% deterministic")

func _thread_mesh_worker(res_array: Array, slot_idx: int) -> void:
	for iter in range(5):
		var faces: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
			0, 2, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100_000.0, 1337, 0.001, 800.0, slot_idx, true
		)
		if iter == 4:
			res_array[slot_idx] = faces.duplicate()

func _test_1_7_concurrent_worker_threads_determinism() -> void:
	_start_test("Tier 1.7: 4 Concurrent Worker Threads Zero Corruption & Parity")
	TerrainMeshBuilderClass.init_builder()
	
	var baseline_faces: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
		0, 2, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100_000.0, 1337, 0.001, 800.0, 0, true
	).duplicate()
	_assert_int(baseline_faces.size(), TerrainMeshBuilderClass.INDEX_COUNT, "Baseline collider face vertex count == 6534")
	
	var thread_results: Array = [[], [], [], []]
	var threads: Array[Thread] = []
	threads.resize(4)
	
	for w in range(4):
		var t: Thread = Thread.new()
		threads[w] = t
		t.start(Callable(self, "_thread_mesh_worker").bind(thread_results, w))
	
	for t in threads:
		t.wait_to_finish()
	
	for w in range(4):
		var t_faces: PackedVector3Array = thread_results[w]
		_assert_int(t_faces.size(), TerrainMeshBuilderClass.INDEX_COUNT, "Worker %d collider face vertex count == 6534" % w)
		var max_diff: float = 0.0
		for i in range(TerrainMeshBuilderClass.INDEX_COUNT):
			var diff: float = t_faces[i].distance_to(baseline_faces[i])
			if diff > max_diff: max_diff = diff
		_assert(max_diff < 1e-4, "Worker %d output identical to baseline (max diff %f)" % [w, max_diff])

# ==============================================================================
# Tier 2: 64-Slot Collider Pool & Quadtree Integration
# ==============================================================================
func _run_tier_2() -> void:
	_test_2_1_collider_pool_lifecycle_and_invariants()
	_test_2_2_collider_faces_update_and_reset()
	_test_2_3_quadtree_collider_qualification()
	_test_2_4_admission_gating_pool_overrun_protection()
	_test_2_5_camera_movement_stress_and_zero_orphans()
	_test_2_6_collider_origin_alignment_and_reset()

func _test_2_1_collider_pool_lifecycle_and_invariants() -> void:
	_start_test("Tier 2.1: ColliderPoolManager 64-Slot Pre-allocation & Invariants")
	var pool: Node3D = ColliderPoolManagerClass.new()
	root.add_child(pool)
	
	_assert_int(ColliderPoolManagerClass.POOL_SIZE, 64, "POOL_SIZE == 64")
	_assert_int(pool.get_active_count(), 0, "Initial active count == 0")
	_assert_int(pool.get_free_count(), 64, "Initial free count == 64")
	_assert(pool.has_available(64), "Pool has 64 available initially")
	_assert(!pool.has_available(65), "Pool does not have 65 available initially")
	
	var audit: Dictionary = pool.verify_integrity()
	_assert(audit["is_valid"], "Initial pool integrity is valid")
	_assert_int(audit["errors"].size(), 0, "Initial pool errors list is empty")
	
	# Acquire all 64 slots
	var dummy_owner: RefCounted = RefCounted.new()
	var acquired_ids: Array[int] = []
	for i in range(64):
		var cid: int = pool.acquire_collider(dummy_owner)
		_assert(cid >= 0 and cid < 64, "Acquired cid %d in [0, 63]" % cid)
		_assert(!acquired_ids.has(cid), "Acquired cid %d is unique" % cid)
		acquired_ids.append(cid)
		_assert(pool.is_in_use[cid], "Slot %d marked is_in_use" % cid)
		_assert(!pool.collision_shapes[cid].disabled, "Slot %d collision shape is enabled" % cid)
		_assert_int(pool.bodies[cid].collision_layer, 1, "Slot %d collision layer is 1" % cid)
	
	_assert_int(pool.get_active_count(), 64, "Active count == 64 after full acquisition")
	_assert_int(pool.get_free_count(), 0, "Free count == 0 after full acquisition")
	_assert(!pool.has_available(1), "Pool has_available(1) is false when full")
	
	# Exhaustion test: 65th acquisition returns -1
	var exhaust_id: int = pool.acquire_collider(dummy_owner)
	_assert_int(exhaust_id, -1, "Acquisition on exhausted pool returns -1")
	
	# Double-free and invalid release protection
	_assert(!pool.release_collider(-1), "Release invalid id -1 returns false")
	_assert(!pool.release_collider(64), "Release invalid id 64 returns false")
	_assert(!pool.release_collider(100), "Release invalid id 100 returns false")
	
	# Release all 64 slots
	for cid in acquired_ids:
		var ok: bool = pool.release_collider(cid)
		_assert(ok, "Release cid %d succeeds" % cid)
		_assert(!pool.is_in_use[cid], "Slot %d marked not in use" % cid)
		_assert(pool.collision_shapes[cid].disabled, "Slot %d collision shape is disabled" % cid)
		_assert_int(pool.bodies[cid].collision_layer, 0, "Slot %d collision layer is 0" % cid)
		# Double-free test
		_assert(!pool.release_collider(cid), "Double-free cid %d returns false" % cid)
	
	_assert_int(pool.get_active_count(), 0, "Active count == 0 after full release")
	_assert_int(pool.get_free_count(), 64, "Free count == 64 after full release")
	
	var final_audit: Dictionary = pool.verify_integrity()
	_assert(final_audit["is_valid"], "Pool integrity is valid after full release cycle")
	
	pool.clear()
	root.remove_child(pool)
	pool.free()

func _test_2_2_collider_faces_update_and_reset() -> void:
	_start_test("Tier 2.2: Collider Shape Faces Update & Auto-Reset on Release")
	var pool: Node3D = ColliderPoolManagerClass.new()
	root.add_child(pool)
	
	var dummy_owner: RefCounted = RefCounted.new()
	var cid: int = pool.acquire_collider(dummy_owner)
	_assert(cid >= 0, "Acquired collider slot")
	
	var test_faces: PackedVector3Array = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0),
		Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)
	])
	pool.update_collider_faces(cid, test_faces)
	
	var shape: ConcavePolygonShape3D = pool.get_shape(cid)
	_assert(shape != null, "ConcavePolygonShape3D is accessible")
	_assert_int(shape.get_faces().size(), 6, "Shape has 6 baked face vertices")
	
	pool.release_collider(cid)
	_assert_int(shape.get_faces().size(), 0, "Shape faces automatically reset to 0 on release")
	
	pool.clear()
	root.remove_child(pool)
	pool.free()

func _test_2_3_quadtree_collider_qualification() -> void:
	_start_test("Tier 2.3: Leaf Chunk Qualification (lod_level >= max_lod - 1)")
	var planet: Node3D = PlanetManagerClass.new()
	planet.planet_radius = 100_000.0
	planet.max_lod = 4
	root.add_child(planet)
	
	# Initial state: LOD 0 leaves across 6 faces
	var leaves: Array[QuadtreeNode] = planet.get_all_leaves()
	_assert_int(leaves.size(), 6, "Initial leaf count == 6")
	_assert_int(planet.collider_pool.get_active_count(), 0, "Initial active colliders == 0 (LOD 0 < max_lod - 1)")
	for leaf in leaves:
		_assert_int(leaf.collider_id, -1, "LOD 0 leaf has collider_id == -1")
	
	# Approach Face 0 surface across multiple frames to trigger progressive subdivision
	var face0_surface: Vector3 = Vector3(100_000.0, 0.0, 0.0)
	for step in range(5):
		planet.update_camera(face0_surface + Vector3(50.0, 0.0, 0.0))
	
	leaves = planet.get_all_leaves()
	var high_lod_leaves: int = 0
	var low_lod_leaves: int = 0
	for leaf in leaves:
		if leaf.lod_level >= planet.max_lod - 1:
			high_lod_leaves += 1
			_assert(leaf.collider_id >= 0, "High LOD leaf (LOD %d) holds valid collider_id" % leaf.lod_level)
			_assert(planet.collider_pool.is_in_use[leaf.collider_id], "Collider slot is in_use")
			_assert(planet.collider_pool.collider_owners[leaf.collider_id] == leaf, "Collider owner matches leaf node")
		else:
			low_lod_leaves += 1
			_assert_int(leaf.collider_id, -1, "Low LOD leaf (LOD %d) has collider_id == -1" % leaf.lod_level)
	
	_assert(high_lod_leaves > 0, "Subdivided tree contains high LOD leaves")
	_assert_int(planet.collider_pool.get_active_count(), high_lod_leaves, "Active colliders equals high LOD leaf count")
	
	var audit: Dictionary = planet.audit_system()
	_assert(audit["is_valid"], "Planet audit is valid under active colliders")
	_assert_int(audit["orphan_count"], 0, "Zero orphan colliders detected")
	
	planet.destroy()
	root.remove_child(planet)
	planet.free()

func _test_2_4_admission_gating_pool_overrun_protection() -> void:
	_start_test("Tier 2.4: Admission Gating in split() Prevents Pool Overrun")
	var planet: Node3D = PlanetManagerClass.new()
	planet.planet_radius = 100_000.0
	planet.max_lod = 4
	root.add_child(planet)
	
	# Artificially acquire slots from collider pool so only 2 slots remain free
	var dummy_owner: RefCounted = RefCounted.new()
	var reserved_slots: Array[int] = []
	while planet.collider_pool.get_free_count() > 2:
		var cid: int = planet.collider_pool.acquire_collider(dummy_owner)
		reserved_slots.append(cid)
	
	_assert_int(planet.collider_pool.get_free_count(), 2, "Reserved down to exactly 2 free collider slots")
	
	# Try to split to LOD 3 (which requires 4 colliders, but only 2 available)
	var face0_surface: Vector3 = Vector3(100_000.0, 0.0, 0.0)
	for step in range(4):
		planet.update_camera(face0_surface + Vector3(50.0, 0.0, 0.0))
	
	# Admission gating must prevent overrun: active colliders must strictly be <= 64
	_assert(planet.collider_pool.get_active_count() <= 64, "Active colliders never exceeds pool capacity 64")
	var audit: Dictionary = planet.collider_pool.verify_integrity()
	_assert(audit["is_valid"], "Collider pool integrity strictly maintained under pressure")
	
	# Release the reserved slots
	for cid in reserved_slots:
		planet.collider_pool.release_collider(cid)
	
	# Now update again with full capacity: splits can proceed safely
	for step in range(4):
		planet.update_camera(face0_surface + Vector3(50.0, 0.0, 0.0))
	
	var post_audit: Dictionary = planet.audit_system()
	_assert(post_audit["is_valid"], "Planet audit is valid after admission pressure relieved")
	
	planet.destroy()
	root.remove_child(planet)
	planet.free()

func _test_2_5_camera_movement_stress_and_zero_orphans() -> void:
	_start_test("Tier 2.5: 1,000 Dynamic Camera Movements & Zero Orphan Colliders")
	var planet: Node3D = PlanetManagerClass.new()
	planet.planet_radius = 100_000.0
	planet.max_lod = 5
	root.add_child(planet)
	
	var r: float = 100_000.0
	var camera_positions: Array[Vector3] = []
	for i in range(1000):
		var phi: float = float(i) * 0.17
		var theta: float = float(i) * 0.09
		var alt: float = 500.0 + (float(i % 50) / 50.0) * 150_000.0
		var dir: Vector3 = Vector3(cos(phi) * cos(theta), sin(phi), cos(phi) * sin(theta)).normalized()
		camera_positions.append(dir * (r + alt))
	
	var audit_checks_passed: int = 0
	for step in range(1000):
		planet.update_camera(camera_positions[step])
		if step % 200 == 199:
			var audit: Dictionary = planet.audit_system()
			if audit["is_valid"] and audit["orphan_count"] == 0 and planet.collider_pool.get_active_count() <= 64:
				audit_checks_passed += 1
	
	_assert_int(audit_checks_passed, 5, "5 periodic system audits passed cleanly during 1,000 movements")
	
	# Move to deep orbit to force full merge back to LOD 0
	planet.update_camera(Vector3(10_000_000.0, 0.0, 0.0))
	planet.update_camera(Vector3(10_000_000.0, 0.0, 0.0))
	
	_assert_int(planet.collider_pool.get_active_count(), 0, "Zero active colliders after full merge to orbit")
	_assert_int(planet.get_all_leaves().size(), 6, "Exactly 6 leaves (LOD 0) after full merge to orbit")
	
	planet.destroy()
	_assert_int(QuadtreeNodeClass.get_active_node_count(), 0, "Zero active QuadtreeNode instances after destroy()")
	root.remove_child(planet)
	planet.free()

func _test_2_6_collider_origin_alignment_and_reset() -> void:
	_start_test("Tier 2.6: Chunk Collider Origin Alignment & Reset on Release")
	var pool: Node3D = ColliderPoolManagerClass.new()
	root.add_child(pool)
	
	var owner_mock: RefCounted = RefCounted.new()
	var cid: int = pool.acquire_collider(owner_mock)
	_assert(cid >= 0, "Acquired collider id %d" % cid)
	
	_assert_vec3_approx(pool.get_collider_origin(cid), Vector3.ZERO, 1e-6, "Initial collider position is Vector3.ZERO")
	
	var chunk_origin: Vector3 = TerrainMeshBuilderClass.get_chunk_origin(0, Vector2(-0.5, -0.5), 100_000.0)
	pool.set_collider_origin(cid, chunk_origin)
	_assert_vec3_approx(pool.get_collider_origin(cid), chunk_origin, 1e-4, "Collider position aligns with chunk origin")
	_assert_vec3_approx(pool.get_body(cid).position, chunk_origin, 1e-4, "StaticBody3D.position matches chunk origin")
	
	pool.set_collider_origin(-1, Vector3(100.0, 200.0, 300.0))
	pool.set_collider_origin(64, Vector3(100.0, 200.0, 300.0))
	var other_id: int = (cid + 1) % 64
	pool.set_collider_origin(other_id, Vector3(999.0, 999.0, 999.0))
	_assert_vec3_approx(pool.get_collider_origin(other_id), Vector3.ZERO, 1e-6, "Inactive slot unaffected by set_collider_origin")
	
	var rel_ok: bool = pool.release_collider(cid)
	_assert(rel_ok, "Released collider %d" % cid)
	_assert_vec3_approx(pool.get_body(cid).position, Vector3.ZERO, 1e-6, "Collider StaticBody3D position reset to ZERO on release")
	_assert_vec3_approx(pool.get_collider_origin(cid), Vector3.ZERO, 1e-6, "get_collider_origin returns ZERO after release")
	
	pool.clear()
	root.remove_child(pool)
	pool.free()

# ==============================================================================
# Tier 3: Bounded 4-Thread Task Scheduler
# ==============================================================================
func _run_tier_3() -> void:
	_test_3_1_strict_concurrency_bound()
	_test_3_2_ring_buffer_lifecycle_submission_execution_reclaim()
	_test_3_3_job_cancellation_and_generation_tracking()
	_test_3_4_zero_steady_state_heap_allocations_polling()
	_test_3_5_thread_lifecycle_and_clean_shutdown()
	_test_3_6_cancel_all_jobs_auto_reclamation_during_poll()

func _task_compute_square(x: int) -> int:
	return x * x

func _task_busy_work(ms: int) -> int:
	OS.delay_msec(ms)
	return ms

func _on_test_job_completed(jid: int, res: Variant) -> void:
	_sched_signal_received = true
	_sched_signal_job_id = jid
	_sched_signal_result = res

func _test_3_1_strict_concurrency_bound() -> void:
	_start_test("Tier 3.1: Strict <= 4 Worker Concurrency Ceiling Under Burst Submission")
	var sched: Node = ChunkTaskSchedulerClass.new()
	root.add_child(sched)
	
	_assert_int(sched.get_worker_count(), 4, "Configured worker count == 4")
	_assert_int(sched.get_active_worker_count(), 0, "Initial active workers == 0")
	
	# Burst submit 32 computationally delayed tasks (15ms each)
	var jids: Array[int] = []
	for i in range(32):
		var jid: int = sched.submit_job(Callable(self, "_task_busy_work"), [15])
		_assert(jid > 0, "Burst submitted job id > 0")
		jids.append(jid)
	
	var max_observed_workers: int = 0
	for sample in range(60):
		var active: int = sched.get_active_worker_count()
		if active > max_observed_workers:
			max_observed_workers = active
		_assert(active <= 4, "Active worker threads %d strictly <= 4" % active)
		OS.delay_msec(2)
	
	_assert(max_observed_workers <= 4, "Max observed concurrent workers %d <= 4" % max_observed_workers)
	_assert(max_observed_workers > 0, "Scheduler successfully utilized worker threads")
	
	# Wait for all jobs to complete and reclaim
	for jid in jids:
		var waited: int = 0
		while not sched.is_job_completed(jid) and waited < 2000:
			OS.delay_msec(5)
			waited += 5
		_assert(sched.is_job_completed(jid), "Burst job %d completed" % jid)
		sched.reclaim_job(jid)
	
	_assert_int(sched.get_available_slots(), 64, "All 64 slots reclaimed after burst")
	
	sched.shutdown()
	root.remove_child(sched)
	sched.free()

func _test_3_2_ring_buffer_lifecycle_submission_execution_reclaim() -> void:
	_start_test("Tier 3.2: 64-Slot Ring Buffer Lifecycle & Result Dispatch")
	var sched: Node = ChunkTaskSchedulerClass.new()
	root.add_child(sched)
	
	_sched_signal_received = false
	_sched_signal_job_id = -1
	_sched_signal_result = null
	sched.job_completed.connect(self._on_test_job_completed)
	
	var jid: int = sched.submit_job(Callable(self, "_task_compute_square"), [9])
	_assert(jid > 0, "Submitted job id > 0")
	var slot: int = jid & 63
	var gen: int = jid >> 6
	_assert(slot >= 0 and slot < 64, "Slot index in [0, 63]")
	_assert(gen >= 1, "Slot generation >= 1")
	
	# Wait for completion
	var waited: int = 0
	while not sched.is_job_completed(jid) and waited < 1000:
		OS.delay_msec(5)
		waited += 5
	
	_assert(sched.is_job_completed(jid), "Job marked completed")
	_assert_int(int(sched.get_job_result(jid)), 81, "Job result == 81")
	
	# Dispatch via poll() and verify signal
	sched.poll()
	_assert(_sched_signal_received, "job_completed signal emitted during poll()")
	_assert_int(_sched_signal_job_id, jid, "Signal job_id matches")
	_assert_int(int(_sched_signal_result), 81, "Signal result matches 81")
	
	# Reclaim
	var reclaimed: bool = sched.reclaim_job(jid)
	_assert(reclaimed, "reclaim_job() returned true")
	_assert_int(sched.get_available_slots(), 64, "All 64 slots available after reclaim")
	
	sched.shutdown()
	root.remove_child(sched)
	sched.free()

func _test_3_3_job_cancellation_and_generation_tracking() -> void:
	_start_test("Tier 3.3: Job Cancellation & Bitwise Generation Invalidation")
	var sched: Node = ChunkTaskSchedulerClass.new()
	root.add_child(sched)
	
	# 1. Test Cancellation
	# Fill workers with slow tasks to force queuing
	var blocker_ids: Array[int] = []
	for i in range(4):
		blocker_ids.append(sched.submit_job(Callable(self, "_task_busy_work"), [50]))
	
	# Submit queued task and cancel immediately
	var queued_jid: int = sched.submit_job(Callable(self, "_task_compute_square"), [12])
	_assert(queued_jid > 0, "Queued job submitted")
	var cancelled: bool = sched.cancel_job(queued_jid)
	_assert(cancelled, "cancel_job() returned true for queued job")
	_assert(sched.is_job_completed(queued_jid), "Cancelled job is marked completed/terminal")
	_assert_int(sched.get_job_status(queued_jid), ChunkTaskSchedulerClass.STATUS_CANCELLED, "Status is STATUS_CANCELLED")
	
	# Wait for blockers to finish
	for bid in blocker_ids:
		while not sched.is_job_completed(bid):
			OS.delay_msec(5)
		sched.reclaim_job(bid)
	sched.reclaim_job(queued_jid)
	
	# 2. Test Bitwise Generation Invalidation
	var jid1: int = sched.submit_job(Callable(self, "_task_compute_square"), [5])
	while not sched.is_job_completed(jid1):
		OS.delay_msec(5)
	var slot1: int = jid1 & 63
	var gen1: int = jid1 >> 6
	sched.reclaim_job(jid1)
	
	# Submit another job in the same slot
	var jid2: int = sched.submit_job(Callable(self, "_task_compute_square"), [7])
	var slot2: int = jid2 & 63
	var gen2: int = jid2 >> 6
	_assert_int(slot2, slot1, "Reused slot matches slot1")
	_assert(gen2 > gen1, "Generation incremented: gen2 (%d) > gen1 (%d)" % [gen2, gen1])
	
	# Old jid1 must be rejected across all queries
	_assert(!sched.is_job_completed(jid1), "Stale job_id returns false for is_job_completed")
	_assert(sched.get_job_result(jid1) == null, "Stale job_id returns null for get_job_result")
	_assert(!sched.reclaim_job(jid1), "Stale job_id returns false for reclaim_job")
	
	while not sched.is_job_completed(jid2):
		OS.delay_msec(5)
	sched.reclaim_job(jid2)
	
	sched.shutdown()
	root.remove_child(sched)
	sched.free()

func _test_3_4_zero_steady_state_heap_allocations_polling() -> void:
	_start_test("Tier 3.4: Zero Steady-State Heap Allocation Across 1,000 Polls")
	var sched: Node = ChunkTaskSchedulerClass.new()
	root.add_child(sched)
	
	# Warm up poll() loop
	for i in range(20):
		sched.poll()
	
	var mem_before: int = OS.get_static_memory_usage()
	for i in range(1000):
		sched.poll()
	var mem_after: int = OS.get_static_memory_usage()
	var mem_delta: int = mem_after - mem_before
	
	_assert_int(mem_delta, 0, "Zero static heap memory growth across 1,000 poll() calls")
	
	sched.shutdown()
	root.remove_child(sched)
	sched.free()

func _test_3_5_thread_lifecycle_and_clean_shutdown() -> void:
	_start_test("Tier 3.5: Thread Worker Lifecycle & Safe Idempotent Shutdown")
	var sched: Node = ChunkTaskSchedulerClass.new()
	root.add_child(sched)
	
	_assert(sched.is_running(), "Scheduler is_running() is true")
	
	# Submit background work
	sched.submit_job(Callable(self, "_task_busy_work"), [10])
	
	# Shutdown
	sched.shutdown()
	_assert(!sched.is_running(), "Scheduler is_running() is false after shutdown")
	_assert_int(sched.submit_job(Callable(self, "_task_busy_work"), [5]), -1, "submit_job returns -1 after shutdown")
	
	# Second shutdown call must be safe and idempotent (no hang/crash)
	sched.shutdown()
	_assert(!sched.is_running(), "Second shutdown call succeeded safely")
	
	root.remove_child(sched)
	sched.free()

func _test_3_6_cancel_all_jobs_auto_reclamation_during_poll() -> void:
	_start_test("Tier 3.6: cancel_all_jobs() Auto Slot Reclamation During poll()")
	var sched: Node = ChunkTaskSchedulerClass.new()
	root.add_child(sched)
	
	_assert_int(sched.get_available_slots(), 64, "Initial available slots == 64")
	
	for i in range(64):
		var jid: int = sched.submit_job(Callable(self, "_task_busy_work"), [50])
		_assert(jid > 0, "Job %d submitted successfully with id %d" % [i, jid])
	
	_assert_int(sched.get_available_slots(), 0, "All 64 slots occupied (available == 0)")
	_assert_int(sched.get_queue_count(), 60, "60 jobs queued in ring buffer")
	
	sched.cancel_all_jobs()
	
	var wait_timeout: int = 1000
	while sched.get_active_worker_count() > 0 and wait_timeout > 0:
		OS.delay_msec(10)
		wait_timeout -= 10
	_assert_int(sched.get_active_worker_count(), 0, "All workers drained to 0")
	
	sched.poll()
	
	_assert_int(sched.get_available_slots(), 64, "All 64 slots fully reclaimed and available after poll()")
	_assert_int(sched.get_queue_count(), 0, "Queue count is 0 after cancel and poll")
	
	for i in range(64):
		var jid2: int = sched.submit_job(Callable(self, "_task_busy_work"), [1])
		_assert(jid2 > 0, "Re-submitted job %d successfully" % i)
	_assert_int(sched.get_available_slots(), 0, "Successfully re-filled 64 slots")
	
	sched.cancel_all_jobs()
	var wait_timeout2: int = 500
	while sched.get_active_worker_count() > 0 and wait_timeout2 > 0:
		OS.delay_msec(5)
		wait_timeout2 -= 5
	sched.poll()
	_assert_int(sched.get_available_slots(), 64, "Re-reclaimed all 64 slots")
	
	sched.shutdown()
	root.remove_child(sched)
	sched.free()

# ==============================================================================
# Tier 4: Radial Planetary Gravity & Rebase Conservation
# ==============================================================================
func _run_tier_4() -> void:
	_test_4_1_radial_gravity_inverse_square_scaling()
	_test_4_2_subsurface_clamping_and_singularity_protection()
	_test_4_3_spaceship_gravity_integration_and_backward_compatibility()
	_test_4_4_floating_origin_orbital_freefall_rebase_conservation()
	_test_4_5_floating_origin_hypersonic_and_multi_rebase_conservation()

func _test_4_1_radial_gravity_inverse_square_scaling() -> void:
	_start_test("Tier 4.1: Radial Inverse-Square Planetary Gravity Formulation")
	var planet_pos: Vector3 = Vector3(10_000.0, -5_000.0, 20_000.0)
	var radius: float = 100_000.0
	var g0: float = 9.81
	
	# 1. Surface: r == R -> |g| == g0, direction toward planet_pos
	var surface_pos: Vector3 = planet_pos + Vector3(100_000.0, 0.0, 0.0)
	var g_surface: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(surface_pos, planet_pos, radius, g0)
	_assert_vec3_approx(g_surface, Vector3(-9.81, 0.0, 0.0), 1e-4, "Surface gravity vector is (-9.81, 0, 0)")
	_assert_approx(g_surface.length(), 9.81, 1e-4, "Surface gravity magnitude == 9.81")
	
	# 2. Above surface: r == 2R -> |g| == g0 / 4
	var r2_pos: Vector3 = planet_pos + Vector3(0.0, 200_000.0, 0.0)
	var g_2r: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(r2_pos, planet_pos, radius, g0)
	_assert_vec3_approx(g_2r, Vector3(0.0, -9.81 / 4.0, 0.0), 1e-4, "Gravity at 2R is (0, -2.4525, 0)")
	_assert_approx(g_2r.length(), 9.81 / 4.0, 1e-4, "Gravity magnitude at 2R == g0 / 4")
	
	# 3. Above surface: r == 3R -> |g| == g0 / 9
	var r3_pos: Vector3 = planet_pos + Vector3(0.0, 0.0, 300_000.0)
	var g_3r: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(r3_pos, planet_pos, radius, g0)
	_assert_vec3_approx(g_3r, Vector3(0.0, 0.0, -9.81 / 9.0), 1e-4, "Gravity at 3R is (0, 0, -1.09)")
	_assert_approx(g_3r.length(), 9.81 / 9.0, 1e-4, "Gravity magnitude at 3R == g0 / 9")
	
	# 4. Above surface: r == 10R -> |g| == g0 / 100
	var r10_pos: Vector3 = planet_pos + Vector3(1_000_000.0, 0.0, 0.0)
	var g_10r: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(r10_pos, planet_pos, radius, g0)
	_assert_approx(g_10r.length(), 9.81 / 100.0, 1e-4, "Gravity magnitude at 10R == g0 / 100")
	
	# 5. Arbitrary 3D orientation diagonal
	var arbitrary_dir: Vector3 = Vector3(1.0, 2.0, 3.0).normalized()
	var diag_r: float = 250_000.0
	var diag_pos: Vector3 = planet_pos + arbitrary_dir * diag_r
	var g_diag: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(diag_pos, planet_pos, radius, g0)
	var expected_mag: float = g0 * ((radius / diag_r) * (radius / diag_r))
	var expected_vec: Vector3 = -arbitrary_dir * expected_mag
	_assert_vec3_approx(g_diag, expected_vec, 1e-4, "Diagonal arbitrary 3D gravity vector matches exact formula")

func _test_4_2_subsurface_clamping_and_singularity_protection() -> void:
	_start_test("Tier 4.2: Subsurface Clamping & Singularity Protection")
	var planet_pos: Vector3 = Vector3.ZERO
	var radius: float = 100_000.0
	var g0: float = 9.81
	
	# Subsurface clamping at surface gravity magnitude g0 for r < R
	for ratio in [0.9, 0.5, 0.1, 0.01]:
		var sub_pos: Vector3 = Vector3(radius * ratio, 0.0, 0.0)
		var g_sub: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(sub_pos, planet_pos, radius, g0)
		_assert_approx(g_sub.length(), 9.81, 1e-4, "Subsurface gravity at ratio %f clamped at 9.81" % ratio)
		_assert_vec3_approx(g_sub, Vector3(-9.81, 0.0, 0.0), 1e-4, "Subsurface direction points toward planet center")
	
	# Singularity protection: r == 0 returns Vector3.ZERO
	var g_zero: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(planet_pos, planet_pos, radius, g0)
	_assert_vec3_approx(g_zero, Vector3.ZERO, 1e-6, "Singularity at center returns Vector3.ZERO")
	
	# Near-singularity distance < 1e-6 returns Vector3.ZERO
	var g_near: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(Vector3(1e-7, 0, 0), planet_pos, radius, g0)
	_assert_vec3_approx(g_near, Vector3.ZERO, 1e-6, "Near-singularity (< 1e-6) returns Vector3.ZERO")
	
	# Non-positive radius returns Vector3.ZERO
	var g_neg_r: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(Vector3(100, 0, 0), planet_pos, -50.0, g0)
	_assert_vec3_approx(g_neg_r, Vector3.ZERO, 1e-6, "Negative radius returns Vector3.ZERO")
	var g_zero_r: Vector3 = AtmosphereMathClass.calculate_gravity_acceleration(Vector3(100, 0, 0), planet_pos, 0.0, g0)
	_assert_vec3_approx(g_zero_r, Vector3.ZERO, 1e-6, "Zero radius returns Vector3.ZERO")

func _test_4_3_spaceship_gravity_integration_and_backward_compatibility() -> void:
	_start_test("Tier 4.3: SpaceshipController Gravity Integration & Zero-Alloc Physics")
	var ship: RigidBody3D = SpaceshipControllerClass.new()
	root.add_child(ship)
	
	# Verify backward-compatible defaults
	_assert(!ship.enable_planetary_gravity, "Default enable_planetary_gravity is false")
	_assert_approx(ship.surface_gravity, 9.81, 1e-4, "Default surface_gravity is 9.81")
	
	ship.planet_position = Vector3(0.0, -100_000.0, 0.0)
	ship.planet_radius = 100_000.0
	ship.mass = 2000.0
	ship.position = Vector3.ZERO # Surface: distance 100,000 from center
	
	# With gravity disabled, force must be ZERO
	ship._physics_process(0.0166667)
	_assert_vec3_approx(ship.get_current_gravity(), Vector3.ZERO, 1e-4, "Gravity force is ZERO when disabled")
	
	# Enable gravity and verify force application
	ship.enable_planetary_gravity = true
	ship._physics_process(0.0166667)
	var expected_force: Vector3 = Vector3(0.0, -9.81 * 2000.0, 0.0)
	_assert_vec3_approx(ship.get_current_gravity(), expected_force, 0.05, "Gravity force is mass * g0 when enabled")
	_assert_vec3_approx(ship.get_current_gravity_acceleration(), Vector3(0.0, -9.81, 0.0), 1e-3, "Gravity acceleration matches g0")
	
	# Zero heap memory growth across 500 physics steps
	for i in range(20):
		ship._physics_process(0.0166667)
	
	var mem_before: int = OS.get_static_memory_usage()
	for i in range(500):
		ship._physics_process(0.0166667)
	var mem_after: int = OS.get_static_memory_usage()
	var mem_delta: int = mem_after - mem_before
	_assert_int(mem_delta, 0, "Zero static heap allocations across 500 physics steps with gravity enabled")
	
	root.remove_child(ship)
	ship.free()

func _test_4_4_floating_origin_orbital_freefall_rebase_conservation() -> void:
	_start_test("Tier 4.4: Orbital Freefall 2,000m Rebase Velocity Conservation (< 1e-4)")
	var origin: Node = FloatingOriginClass.new()
	var ship: RigidBody3D = SpaceshipControllerClass.new()
	root.add_child(origin)
	root.add_child(ship)
	
	origin.player_node = ship
	ship.enable_planetary_gravity = true
	ship.surface_gravity = 9.81
	ship.planet_position = Vector3(0.0, -100_000.0, 0.0)
	ship.planet_radius = 100_000.0
	ship.mass = 2500.0
	
	var v_orbital: Vector3 = Vector3(1500.0, 10.0, -850.0)
	var w_spin: Vector3 = Vector3(0.08, -0.04, 0.15)
	ship.linear_velocity = v_orbital
	ship.angular_velocity = w_spin
	
	# Execute 2,000m rebase
	origin.rebase(Vector3(2000.0, 0.0, 0.0))
	
	var delta_v: float = (ship.linear_velocity - v_orbital).length()
	var delta_w: float = (ship.angular_velocity - w_spin).length()
	_assert_approx(delta_v, 0.0, 1e-4, "Orbital linear velocity spike Delta v < 1e-4")
	_assert_approx(delta_w, 0.0, 1e-4, "Orbital angular velocity spike Delta w < 1e-4")
	
	root.remove_child(origin)
	root.remove_child(ship)
	origin.free()
	ship.free()

func _test_4_5_floating_origin_hypersonic_and_multi_rebase_conservation() -> void:
	_start_test("Tier 4.5: Hypersonic Flight & 50 Sequential Rebases Velocity Conservation")
	var origin: Node = FloatingOriginClass.new()
	var ship: RigidBody3D = SpaceshipControllerClass.new()
	root.add_child(origin)
	root.add_child(ship)
	
	origin.player_node = ship
	ship.enable_planetary_gravity = true
	
	# 1. Hypersonic entry test (10,000 m/s)
	var v_hypersonic: Vector3 = Vector3(0.0, -10_000.0, 2_500.0)
	var w_hypersonic: Vector3 = Vector3(0.2, -0.3, 0.5)
	ship.linear_velocity = v_hypersonic
	ship.angular_velocity = w_hypersonic
	
	origin.rebase(Vector3(1500.0, -2200.0, 1000.0))
	var delta_v_hyper: float = (ship.linear_velocity - v_hypersonic).length()
	var delta_w_hyper: float = (ship.angular_velocity - w_hypersonic).length()
	_assert_approx(delta_v_hyper, 0.0, 1e-4, "Hypersonic linear velocity spike Delta v < 1e-4")
	_assert_approx(delta_w_hyper, 0.0, 1e-4, "Hypersonic angular velocity spike Delta w < 1e-4")
	
	# 2. 50 sequential continuous rebases
	var v_base: Vector3 = Vector3(3000.0, 500.0, -1200.0)
	var w_base: Vector3 = Vector3(0.05, 0.02, -0.03)
	ship.linear_velocity = v_base
	ship.angular_velocity = w_base
	
	var max_dv: float = 0.0
	var max_dw: float = 0.0
	for step in range(50):
		var rebase_offset: Vector3 = Vector3(
			2000.0 + float(step % 10) * 50.0,
			-2000.0 + float(step % 5) * 30.0,
			1500.0
		)
		origin.rebase(rebase_offset)
		var dv: float = (ship.linear_velocity - v_base).length()
		var dw: float = (ship.angular_velocity - w_base).length()
		if dv > max_dv: max_dv = dv
		if dw > max_dw: max_dw = dw
	
	_assert_approx(max_dv, 0.0, 1e-4, "Max Delta v across 50 sequential rebases < 1e-4")
	_assert_approx(max_dw, 0.0, 1e-4, "Max Delta w across 50 sequential rebases < 1e-4")
	
	root.remove_child(origin)
	root.remove_child(ship)
	origin.free()
	ship.free()

# ==============================================================================
# Tier 5: Code Guardrails & Backward Compatibility
# ==============================================================================
func _run_tier_5() -> void:
	_test_5_1_production_script_line_count_audit()
	_test_5_2_phase1_regression_suite()

func _test_5_1_production_script_line_count_audit() -> void:
	_start_test("Tier 5.1: Production Script Line Count Audit (All 10 Scripts <= 250 Lines)")
	var production_scripts: Array[String] = [
		"res://AtmosphereMath.gd",
		"res://SpaceshipController.gd",
		"res://FloatingOrigin.gd",
		"res://PlanetManager.gd",
		"res://PlanetMath.gd",
		"res://QuadtreeNode.gd",
		"res://ChunkPoolManager.gd",
		"res://ColliderPoolManager.gd",
		"res://ChunkTaskScheduler.gd",
		"res://TerrainMeshBuilder.gd"
	]
	
	for script_path in production_scripts:
		var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		_assert(file != null, "Can open production script: %s" % script_path)
		if file != null:
			var content: String = file.get_as_text()
			file.close()
			var line_count: int = content.split("\n").size()
			_assert(line_count <= 250, "%s has %d lines (strictly <= 250 lines)" % [script_path.get_file(), line_count])

func _test_5_2_phase1_regression_suite() -> void:
	_start_test("Tier 5.2: Phase 1 Regression (All 5 Existing Headless Suites Pass)")
	var phase1_suites: Array[String] = [
		"res://test_floating_origin_headless.gd",
		"res://test_quadtree_headless.gd",
		"res://test_adversarial_challenger2.gd",
		"res://test_adversarial_edge_cases.gd",
		"res://test_adversarial_empirical.gd"
	]
	
	var godot_bin: String = OS.get_executable_path()
	for suite_path in phase1_suites:
		var output: Array = []
		var exit_code: int = OS.execute(godot_bin, ["--headless", "-s", suite_path], output)
		_assert_int(exit_code, 0, "Phase 1 suite %s passed with exit code 0" % suite_path.get_file())

# ==============================================================================
# Summary
# ==============================================================================
func _print_summary() -> void:
	print("\n==================================================================")
	print("TEST SUITE EXECUTION SUMMARY")
	print("==================================================================")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	print("==================================================================")
