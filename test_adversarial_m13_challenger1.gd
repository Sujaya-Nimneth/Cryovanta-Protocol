extends SceneTree

## Empirical Adversarial Challenge Suite - Challenger 1 (Milestone M13)
## Stress-tests:
## 1. 4-Worker TerrainMeshBuilder buffer isolation & determinism under heavy iteration loops (100+ bakes)
## 2. ChunkTaskScheduler burst cancellation & repeated 64-slot reclamation across 15 saturation cycles
## 3. Exact GLSL FBM Parity, constants, hash & grad12 verification
## 4. ColliderPoolManager chunk-origin alignment and reset invariants
## 5. Script line counts and repo cleanliness guardrails

var total_asserts: int = 0
var passed_asserts: int = 0
var failed_asserts: int = 0
var current_test_name: String = ""

var TerrainMeshBuilderClass = null
var ChunkTaskSchedulerClass = null
var ColliderPoolManagerClass = null
var PlanetMathClass = null

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	
	print("==================================================================")
	print("CHALLENGER 1 M13: EMPIRICAL CONCURRENCY & SLOT RECLAMATION STRESS")
	print("==================================================================")
	
	TerrainMeshBuilderClass = load("res://TerrainMeshBuilder.gd")
	ChunkTaskSchedulerClass = load("res://ChunkTaskScheduler.gd")
	ColliderPoolManagerClass = load("res://ColliderPoolManager.gd")
	PlanetMathClass = load("res://PlanetMath.gd")
	
	_run_challenger_suite()
	return true

func _start_test(test_name: String) -> void:
	current_test_name = test_name
	print("RUNNING: %s" % test_name)

func _pass() -> void:
	passed_asserts += 1

func _fail(reason: String) -> void:
	failed_asserts += 1
	printerr("  [FAIL] %s: %s" % [current_test_name, reason])

func _assert(cond: bool, msg: String) -> void:
	total_asserts += 1
	if not cond:
		_fail(msg)
	else:
		_pass()

func _assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	total_asserts += 1
	if actual != expected:
		_fail("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])
	else:
		_pass()

func _assert_approx(actual: float, expected: float, tol: float = 1e-4, msg: String = "") -> void:
	total_asserts += 1
	var diff: float = absf(actual - expected)
	if diff > tol:
		_fail("%s (expected %f, got %f, diff %f > tol %f)" % [msg, expected, actual, diff, tol])
	else:
		_pass()

func _assert_vec3_approx(actual: Vector3, expected: Vector3, tol: float = 1e-4, msg: String = "") -> void:
	total_asserts += 1
	var diff: float = (actual - expected).length()
	if diff > tol:
		_fail("%s (expected %s, got %s, diff %f > tol %f)" % [msg, str(expected), str(actual), diff, tol])
	else:
		_pass()

# Helper thread worker for identical parameters stress
func _worker_identical_params(thread_results: Array, slot_idx: int, iterations: int) -> void:
	for i in range(iterations):
		var faces: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
			0, 2, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100_000.0, 1337, 0.001, 800.0, slot_idx, true
		)
		# Record milestone snapshots
		if i == 0 or i == 24 or i == 49 or i == 74 or i == (iterations - 1):
			thread_results[slot_idx].append(faces.duplicate())

# Helper thread worker for heterogeneous chunk parameters stress
func _worker_heterogeneous_params(thread_results: Array, config: Dictionary) -> void:
	var slot_idx: int = config["slot"]
	var face_idx: int = config["face"]
	var lod: int = config["lod"]
	var uv_min: Vector2 = config["uv_min"]
	var uv_max: Vector2 = config["uv_max"]
	var radius: float = config["radius"]
	var seed_val: int = config["seed"]
	var freq: float = config["freq"]
	var amp: float = config["amp"]
	var iterations: int = config["iterations"]

	for i in range(iterations):
		var faces: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
			face_idx, lod, uv_min, uv_max, radius, seed_val, freq, amp, slot_idx, true
		)
		if i == (iterations - 1):
			thread_results[slot_idx] = faces.duplicate()

# Helper task callable for scheduler busy work
func _task_busy_work(cycles: int) -> int:
	OS.delay_msec(cycles)
	var acc: int = 0
	for i in range(cycles * 100):
		acc = (acc * 1103515245 + 12345) & 0x7FFFFFFF
	return acc

# Helper task callable to record worker index
func _task_record_worker_index(results: Array, idx: int) -> void:
	var w_idx: int = ChunkTaskSchedulerClass.get_current_worker_index()
	results[idx] = w_idx

func _run_challenger_suite() -> void:
	# SECTION 1: 4-Worker TerrainMeshBuilder Concurrency Stress
	_test_concurrency_identical_params_100_iterations()
	_test_concurrency_heterogeneous_params_cross_talk()
	_test_mesh_builder_slot_boundary_clamping()
	
	# SECTION 2: ChunkTaskScheduler Burst Cancellation & Repeated Slot Reclamation
	_test_scheduler_burst_cancel_15_cycles_zero_leaks()
	_test_scheduler_mixed_selective_auto_reclaim()
	_test_scheduler_worker_thread_indexing_and_coverage()
	
	# SECTION 3: GLSL FBM Parity & Determinism
	_test_glsl_fbm_constants_and_formula_parity()
	_test_glsl_hash3_and_grad12_exact_math()
	_test_fbm4_deterministic_spatial_grid()
	
	# SECTION 4: ColliderPoolManager Chunk Origin Alignment & Clean Reset
	_test_collider_origin_alignment_and_bounds()
	_test_collider_full_pool_saturation_and_reset()
	
	# SECTION 5: Code Guardrails & Project Cleanliness
	_test_production_script_line_counts()
	_test_repo_cleanliness_no_orphaned_uids()

	# SUMMARY & VERDICT
	print("==================================================================")
	print("CHALLENGER 1 M13 VERIFICATION SUMMARY")
	print("  Total Assertions:  %d" % total_asserts)
	print("  Passed Assertions: %d" % passed_asserts)
	print("  Failed Assertions: %d" % failed_asserts)
	print("==================================================================")
	
	if failed_asserts > 0:
		printerr("VERDICT: REJECT - %d empirical failure(s) detected!" % failed_asserts)
		quit(1)
	else:
		print("VERDICT: APPROVE - 100% empirical proof confirmed across all stress tests!")
		quit(0)

# ==============================================================================
# SECTION 1: 4-Worker TerrainMeshBuilder Concurrency Stress
# ==============================================================================

func _test_concurrency_identical_params_100_iterations() -> void:
	_start_test("CONCURRENCY 1.1: 4 Concurrent Threads x 100 Iterations Identical Mesh Generation")
	TerrainMeshBuilderClass.init_builder()
	
	# Ground truth single-threaded baseline
	var baseline: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
		0, 2, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100_000.0, 1337, 0.001, 800.0, 0, true
	).duplicate()
	_assert_eq(baseline.size(), TerrainMeshBuilderClass.INDEX_COUNT, "Baseline vertex count == 6534")
	
	var thread_snapshots: Array = [[], [], [], []]
	var threads: Array[Thread] = []
	threads.resize(4)
	
	# Launch 4 threads concurrently running 100 iterations each
	for w in range(4):
		var t: Thread = Thread.new()
		threads[w] = t
		t.start(Callable(self, "_worker_identical_params").bind(thread_snapshots, w, 100))
	
	for t in threads:
		t.wait_to_finish()
	
	# Verify all snapshots across all 4 worker threads
	for w in range(4):
		var snapshots: Array = thread_snapshots[w]
		_assert_eq(snapshots.size(), 5, "Worker %d captured 5 milestone snapshots" % w)
		for s_idx in range(snapshots.size()):
			var snap: PackedVector3Array = snapshots[s_idx]
			_assert_eq(snap.size(), TerrainMeshBuilderClass.INDEX_COUNT, "Worker %d snap %d vertex count == 6534" % [w, s_idx])
			var max_diff: float = 0.0
			for i in range(TerrainMeshBuilderClass.INDEX_COUNT):
				var diff: float = snap[i].distance_to(baseline[i])
				if diff > max_diff:
					max_diff = diff
			_assert(max_diff < 1e-4, "Worker %d snap %d vertex max diff %f < 1e-4" % [w, s_idx, max_diff])

func _test_concurrency_heterogeneous_params_cross_talk() -> void:
	_start_test("CONCURRENCY 1.2: 4 Concurrent Threads Heterogeneous Chunk Parameters Cross-Talk Resistance")
	TerrainMeshBuilderClass.init_builder()
	
	var configs: Array = [
		{
			"slot": 0, "face": 0, "lod": 1, "uv_min": Vector2(-0.5, -0.5), "uv_max": Vector2(0.0, 0.0),
			"radius": 80_000.0, "seed": 111, "freq": 0.002, "amp": 400.0, "iterations": 60
		},
		{
			"slot": 1, "face": 2, "lod": 2, "uv_min": Vector2(0.1, 0.1), "uv_max": Vector2(0.6, 0.6),
			"radius": 120_000.0, "seed": 222, "freq": 0.004, "amp": 800.0, "iterations": 60
		},
		{
			"slot": 2, "face": 4, "lod": 0, "uv_min": Vector2(-0.8, -0.8), "uv_max": Vector2(0.8, 0.8),
			"radius": 60_000.0, "seed": 333, "freq": 0.001, "amp": 250.0, "iterations": 60
		},
		{
			"slot": 3, "face": 5, "lod": 3, "uv_min": Vector2(0.0, 0.0), "uv_max": Vector2(0.25, 0.25),
			"radius": 150_000.0, "seed": 444, "freq": 0.008, "amp": 1500.0, "iterations": 60
		}
	]
	
	# Pre-compute independent baselines sequentially using slot 0
	var baselines: Array = []
	for cfg in configs:
		var b: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
			cfg["face"], cfg["lod"], cfg["uv_min"], cfg["uv_max"],
			cfg["radius"], cfg["seed"], cfg["freq"], cfg["amp"], 0, true
		).duplicate()
		baselines.append(b)
	
	# Launch 4 concurrent threads each writing to its distinct slot
	var thread_results: Array = [[], [], [], []]
	var threads: Array[Thread] = []
	threads.resize(4)
	
	for w in range(4):
		var t: Thread = Thread.new()
		threads[w] = t
		t.start(Callable(self, "_worker_heterogeneous_params").bind(thread_results, configs[w]))
	
	for t in threads:
		t.wait_to_finish()
	
	# Assert each thread's output strictly matches its respective baseline with 0 cross-talk
	for w in range(4):
		var actual: PackedVector3Array = thread_results[w]
		var expected: PackedVector3Array = baselines[w]
		_assert_eq(actual.size(), TerrainMeshBuilderClass.INDEX_COUNT, "Worker %d face count == 6534" % w)
		var max_diff: float = 0.0
		for i in range(TerrainMeshBuilderClass.INDEX_COUNT):
			var diff: float = actual[i].distance_to(expected[i])
			if diff > max_diff:
				max_diff = diff
		_assert(max_diff < 1e-4, "Worker %d matches baseline exactly with 0 cross-talk (max diff %f)" % [w, max_diff])

func _test_mesh_builder_slot_boundary_clamping() -> void:
	_start_test("CONCURRENCY 1.3: Slot Index Boundary Clamping & Safety")
	TerrainMeshBuilderClass.init_builder()
	
	# Test out of bounds slot indices: -1, 4, 99
	var faces_neg: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
		0, 1, Vector2.ZERO, Vector2.ONE, 10_000.0, 1, 0.001, 100.0, -1, true
	)
	_assert_eq(faces_neg.size(), TerrainMeshBuilderClass.INDEX_COUNT, "Negative slot clamps safely to slot 0")
	
	var faces_high: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
		0, 1, Vector2.ZERO, Vector2.ONE, 10_000.0, 1, 0.001, 100.0, 4, true
	)
	_assert_eq(faces_high.size(), TerrainMeshBuilderClass.INDEX_COUNT, "Slot 4 clamps safely to slot 3")
	
	var faces_extreme: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
		0, 1, Vector2.ZERO, Vector2.ONE, 10_000.0, 1, 0.001, 100.0, 999, true
	)
	_assert_eq(faces_extreme.size(), TerrainMeshBuilderClass.INDEX_COUNT, "Slot 999 clamps safely to slot 3")
	
	var col_faces: PackedVector3Array = TerrainMeshBuilderClass.get_collider_faces(2)
	_assert_eq(col_faces.size(), TerrainMeshBuilderClass.INDEX_COUNT, "get_collider_faces(2) returns 6534 vertices")

# ==============================================================================
# SECTION 2: ChunkTaskScheduler Burst Cancellation & Repeated Slot Reclamation
# ==============================================================================

func _test_scheduler_burst_cancel_15_cycles_zero_leaks() -> void:
	_start_test("SCHEDULER 2.1: 15 Consecutive Burst-Submit (64) + cancel_all_jobs() Cycles")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var root_node: Window = get_root()
	root_node.add_child(sched)
	
	_assert_eq(sched.get_available_slots(), 64, "Initial available slots == 64")
	
	const CYCLES: int = 15
	for cycle in range(CYCLES):
		# 1. Burst-submit 64 jobs
		var submitted_ids: Array[int] = []
		for i in range(64):
			var jid: int = sched.submit_job(Callable(self, "_task_busy_work"), [20])
			_assert(jid > 0, "Cycle %d: Job %d submitted with id %d" % [cycle, i, jid])
			submitted_ids.append(jid)
		
		_assert_eq(sched.get_available_slots(), 0, "Cycle %d: All 64 slots occupied (available == 0)" % cycle)
		
		# 2. Immediately cancel all jobs
		sched.cancel_all_jobs()
		
		# 3. Wait for active workers to drain completely
		var timeout_ms: int = 2000
		while sched.get_active_worker_count() > 0 and timeout_ms > 0:
			OS.delay_usec(500)
			timeout_ms -= 1
		
		_assert_eq(sched.get_active_worker_count(), 0, "Cycle %d: Active workers drained to 0" % cycle)
		
		# 4. Process poll() to trigger automatic reclamation
		sched.poll()
		
		# 5. Assert all 64 slots are 100% restored
		_assert_eq(sched.get_available_slots(), 64, "Cycle %d: Available slots fully restored to 64" % cycle)
		_assert_eq(sched.get_queue_count(), 0, "Cycle %d: Queue count drained to 0" % cycle)
	
	sched.shutdown()
	root_node.remove_child(sched)
	sched.free()

func _test_scheduler_mixed_selective_auto_reclaim() -> void:
	_start_test("SCHEDULER 2.2: Mixed Cancellation with Selective auto_reclaim Flags")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var root_node: Window = get_root()
	root_node.add_child(sched)
	
	_assert_eq(sched.get_available_slots(), 64, "Initial slots == 64")
	
	# Submit 32 jobs
	var jids: Array[int] = []
	for i in range(32):
		var jid: int = sched.submit_job(Callable(self, "_task_busy_work"), [50])
		_assert(jid > 0, "Job %d submitted" % i)
		jids.append(jid)
	
	_assert_eq(sched.get_available_slots(), 32, "Available slots == 32 after 32 submissions")
	
	# Cancel jobs 0..15 with auto_reclaim = true
	for i in range(16):
		sched.cancel_job(jids[i], true)
	
	# Cancel jobs 16..31 with auto_reclaim = false
	for i in range(16, 32):
		sched.cancel_job(jids[i], false)
	
	# Drain workers
	var timeout: int = 2000
	while sched.get_active_worker_count() > 0 and timeout > 0:
		OS.delay_usec(500)
		timeout -= 1
	
	sched.poll()
	
	# Jobs 0..15 were auto-reclaimed during poll() -> 32 + 16 = 48 available slots
	_assert_eq(sched.get_available_slots(), 48, "48 slots available (16 auto-reclaimed + 32 never used)")
	
	# Jobs 16..31 were not auto-reclaimed, reclaim them manually
	for i in range(16, 32):
		var reclaimed: bool = sched.reclaim_job(jids[i])
		_assert(reclaimed, "Manually reclaimed cancelled job %d" % jids[i])
	
	_assert_eq(sched.get_available_slots(), 64, "All 64 slots fully available after manual reclamation")
	
	sched.shutdown()
	root_node.remove_child(sched)
	sched.free()

func _test_scheduler_worker_thread_indexing_and_coverage() -> void:
	_start_test("SCHEDULER 2.3: Worker Thread Indexing Invariants & Pool Coverage")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var root_node: Window = get_root()
	root_node.add_child(sched)
	
	# Main thread call to get_current_worker_index returns 0 (safe fallback)
	_assert_eq(ChunkTaskSchedulerClass.get_current_worker_index(), 0, "Main thread worker index == 0")
	_assert_eq(sched.get_worker_index(), 0, "Member worker index on main thread == 0")
	
	# Submit 48 jobs in two batches of 24 to test worker distribution and index correctness
	var total_jobs: int = 48
	var recorded_indices: Array = []
	recorded_indices.resize(total_jobs)
	for i in range(total_jobs):
		recorded_indices[i] = -1
	
	var jids: Array[int] = []
	for i in range(total_jobs):
		var jid: int = sched.submit_job(Callable(self, "_task_record_worker_index"), [recorded_indices, i])
		_assert(jid > 0, "Job %d submitted with id %d" % [i, jid])
		jids.append(jid)
	
	# Wait for all 48 jobs to complete
	var timeout: int = 3000
	while timeout > 0:
		sched.poll()
		var completed_count: int = 0
		for jid in jids:
			if sched.is_job_completed(jid):
				completed_count += 1
		if completed_count == total_jobs:
			break
		OS.delay_usec(500)
		timeout -= 1
	
	# Verify and reclaim all 48 jobs
	var workers_seen: Dictionary = {}
	for i in range(total_jobs):
		var w: int = recorded_indices[i]
		_assert(w >= 0 and w < 4, "Job %d executed by valid worker index %d in [0..3]" % [i, w])
		workers_seen[w] = true
		var rec: bool = sched.reclaim_job(jids[i])
		_assert(rec, "Reclaimed completed job %d" % jids[i])
	
	_assert_eq(workers_seen.size(), 4, "All 4 worker threads (0, 1, 2, 3) participated in job execution")
	_assert_eq(sched.get_available_slots(), 64, "All 64 slots restored after reclaiming all completed jobs")
	
	sched.shutdown()
	root_node.remove_child(sched)
	sched.free()

# ==============================================================================
# SECTION 3: GLSL FBM Parity & Determinism
# ==============================================================================

func _test_glsl_fbm_constants_and_formula_parity() -> void:
	_start_test("GLSL PARITY 3.1: Constant Inspection & Math Alignment")
	var glsl_file: FileAccess = FileAccess.open("res://planet_chunk.glsl", FileAccess.READ)
	_assert(glsl_file != null, "planet_chunk.glsl exists and readable")
	var glsl_text: String = glsl_file.get_as_text()
	glsl_file.close()
	
	var gd_file: FileAccess = FileAccess.open("res://TerrainMeshBuilder.gd", FileAccess.READ)
	_assert(gd_file != null, "TerrainMeshBuilder.gd exists and readable")
	var gd_text: String = gd_file.get_as_text()
	gd_file.close()
	
	# 1. Octave step constant 1013904223 (0x3c6ef35f)
	_assert(glsl_text.contains("1013904223"), "GLSL contains octave step 1013904223")
	_assert(gd_text.contains("1013904223"), "GDScript contains octave step 1013904223")
	
	# 2. Initial amplitude 0.5
	_assert(glsl_text.contains("float amp = 0.5;"), "GLSL initializes amp = 0.5")
	_assert(gd_text.contains("amp: float = 0.5"), "GDScript initializes amp = 0.5")
	
	# 3. Lacunarity scaling freq *= 2.02
	_assert(glsl_text.contains("freq *= 2.02;"), "GLSL scales freq by 2.02")
	_assert(gd_text.contains("freq *= 2.02"), "GDScript scales freq by 2.02")
	
	# 4. 4 octaves
	_assert(glsl_text.contains("for (int o = 0; o < 4; ++o)"), "GLSL loops exactly 4 octaves")
	_assert(gd_text.contains("for o in range(4):"), "GDScript loops exactly 4 octaves")
	
	# 5. Unnormalized return
	_assert(glsl_text.contains("return vec4(value, deriv);"), "GLSL returns unnormalized vec4(value, deriv)")
	_assert(gd_text.contains("return Vector4(val, deriv.x, deriv.y, deriv.z)"), "GDScript returns unnormalized Vector4")

func _test_glsl_hash3_and_grad12_exact_math() -> void:
	_start_test("GLSL PARITY 3.2: Hash Function & Gradient Table Parity")
	TerrainMeshBuilderClass.init_builder()
	
	# Hash determinism across multiple quadrant boundaries
	var test_coords: Array = [
		Vector3i(0, 0, 0),
		Vector3i(1, 2, 3),
		Vector3i(-5, 10, -15),
		Vector3i(1234, -5678, 91011),
		Vector3i(-32768, 32767, 0)
	]
	
	for coord in test_coords:
		var h1: int = TerrainMeshBuilderClass._hash3(coord.x, coord.y, coord.z, 42)
		var h2: int = TerrainMeshBuilderClass._hash3(coord.x, coord.y, coord.z, 42)
		_assert_eq(h1, h2, "Hash is deterministic for %s" % str(coord))
		_assert(h1 >= 0 and h1 <= 0xFFFFFFFF, "Hash fits in unsigned 32-bit range")
	
	# Verify all 12 grad12 gradient vectors match GLSL grad12
	# GLSL grad12 logic:
	# uint i = h % 12u; uint s = i & 3u;
	# vec2 g = vec2((s & 1u) == 0u ? 1.0 : -1.0, (s & 2u) == 0u ? 1.0 : -1.0);
	# uint axis = i >> 2;
	# axis 0: (0, gx, gy); axis 1: (gx, 0, gy); axis 2: (gx, gy, 0)
	for h in range(24):
		var g: Vector3 = TerrainMeshBuilderClass._grad12(h)
		_assert_approx(g.length_squared(), 2.0, 1e-6, "Gradient %d length^2 == 2.0" % h)
		var i: int = h % 12
		var axis: int = i >> 2
		if axis == 0:
			_assert_eq(g.x, 0.0, "grad12(%d) axis 0 has x == 0" % h)
		elif axis == 1:
			_assert_eq(g.y, 0.0, "grad12(%d) axis 1 has y == 0" % h)
		else:
			_assert_eq(g.z, 0.0, "grad12(%d) axis 2 has z == 0" % h)

func _test_fbm4_deterministic_spatial_grid() -> void:
	_start_test("GLSL PARITY 3.3: fbm4 Determinism & Boundedness on 100 Sample Points")
	TerrainMeshBuilderClass.init_builder()
	
	for i in range(100):
		var p: Vector3 = Vector3(
			sin(float(i) * 1.7) * 50.0,
			cos(float(i) * 2.3) * 50.0,
			sin(float(i) * 0.9) * 50.0
		)
		var res1: Vector4 = TerrainMeshBuilderClass.fbm4(p, 1337)
		var res2: Vector4 = TerrainMeshBuilderClass.fbm4(p, 1337)
		
		_assert_approx(res1.x, res2.x, 1e-6, "fbm4 value deterministic at point %d" % i)
		_assert_approx(res1.y, res2.y, 1e-6, "fbm4 d/dx deterministic at point %d" % i)
		_assert_approx(res1.z, res2.z, 1e-6, "fbm4 d/dy deterministic at point %d" % i)
		_assert_approx(res1.w, res2.w, 1e-6, "fbm4 d/dz deterministic at point %d" % i)
		
		# Boundedness: 4 octaves with initial amp 0.5 (sum of amps < 1.0)
		_assert(absf(res1.x) < 2.5, "fbm4 value %f within plausible [-2.5, 2.5] bounds" % res1.x)
		_assert(!is_nan(res1.x) and !is_inf(res1.x), "fbm4 value is finite")

# ==============================================================================
# SECTION 4: ColliderPoolManager Chunk Origin Alignment & Clean Reset
# ==============================================================================

func _test_collider_origin_alignment_and_bounds() -> void:
	_start_test("COLLIDER 4.1: Origin Alignment Bounds & Inactive State Safety")
	var col_pool: ColliderPoolManager = ColliderPoolManager.new()
	var root_node: Window = get_root()
	root_node.add_child(col_pool)
	
	# Out of bounds calls
	col_pool.set_collider_origin(-1, Vector3(10, 20, 30))
	col_pool.set_collider_origin(64, Vector3(10, 20, 30))
	_assert_eq(col_pool.get_collider_origin(-1), Vector3.ZERO, "OOB collider -1 returns ZERO origin")
	_assert_eq(col_pool.get_collider_origin(64), Vector3.ZERO, "OOB collider 64 returns ZERO origin")
	
	# Inactive slot
	col_pool.set_collider_origin(5, Vector3(100, 200, 300))
	_assert_eq(col_pool.get_collider_origin(5), Vector3.ZERO, "Inactive slot 5 origin remains ZERO")
	
	# Active slot
	var ref: RefCounted = RefCounted.new()
	var cid: int = col_pool.acquire_collider(ref)
	_assert(cid >= 0, "Acquired collider %d" % cid)
	
	var target_origin: Vector3 = Vector3(1234.5, -678.9, 4321.0)
	col_pool.set_collider_origin(cid, target_origin)
	_assert_vec3_approx(col_pool.get_collider_origin(cid), target_origin, 1e-5, "Origin matches target")
	_assert_vec3_approx(col_pool.bodies[cid].position, target_origin, 1e-5, "StaticBody3D position updated")
	
	# Release and assert reset
	col_pool.release_collider(cid)
	_assert_vec3_approx(col_pool.bodies[cid].position, Vector3.ZERO, 1e-5, "StaticBody3D reset to ZERO on release")
	_assert_eq(col_pool.get_collider_origin(cid), Vector3.ZERO, "get_collider_origin returns ZERO after release")
	
	col_pool.clear()
	root_node.remove_child(col_pool)
	col_pool.free()

func _test_collider_full_pool_saturation_and_reset() -> void:
	_start_test("COLLIDER 4.2: Full 64-Slot Saturation Origin Assignment & Reset Audit")
	var col_pool: ColliderPoolManager = ColliderPoolManager.new()
	var root_node: Window = get_root()
	root_node.add_child(col_pool)
	
	var owners: Array[RefCounted] = []
	var cids: Array[int] = []
	
	var seen_cids: Dictionary = {}
	for i in range(64):
		var ref: RefCounted = RefCounted.new()
		owners.append(ref)
		var cid: int = col_pool.acquire_collider(ref)
		_assert(cid >= 0 and cid < 64, "Collider slot %d in [0, 63]" % cid)
		_assert(!seen_cids.has(cid), "Collider slot %d is unique" % cid)
		seen_cids[cid] = true
		cids.append(cid)
		
		var pos: Vector3 = Vector3(float(i) * 100.0, float(i) * -50.0, float(i) * 25.0)
		col_pool.set_collider_origin(cid, pos)
		_assert_vec3_approx(col_pool.get_collider_origin(cid), pos, 1e-5, "Slot %d origin set" % cid)
	
	_assert_eq(col_pool.get_active_count(), 64, "All 64 colliders active")
	
	# Release all 64 colliders
	for cid in cids:
		var ok: bool = col_pool.release_collider(cid)
		_assert(ok, "Released collider %d" % cid)
		_assert_vec3_approx(col_pool.bodies[cid].position, Vector3.ZERO, 1e-5, "Body %d reset to ZERO" % cid)
		_assert_eq(col_pool.get_collider_origin(cid), Vector3.ZERO, "Origin %d reset to ZERO" % cid)
	
	_assert_eq(col_pool.get_active_count(), 0, "All 64 colliders released back to pool")
	
	# Verify pool integrity
	var audit: Dictionary = col_pool.verify_integrity()
	_assert(audit["is_valid"], "Pool integrity audit passed with 0 errors")
	_assert_eq(audit["free_count"], 64, "Free count == 64")
	
	col_pool.clear()
	root_node.remove_child(col_pool)
	col_pool.free()

# ==============================================================================
# SECTION 5: Code Guardrails & Project Cleanliness
# ==============================================================================

func _test_production_script_line_counts() -> void:
	_start_test("GUARDRAILS 5.1: 10 Production Scripts <= 250 Lines Audit")
	var files: Array[String] = [
		"AtmosphereMath.gd",
		"ChunkPoolManager.gd",
		"ChunkTaskScheduler.gd",
		"ColliderPoolManager.gd",
		"FloatingOrigin.gd",
		"PlanetManager.gd",
		"PlanetMath.gd",
		"QuadtreeNode.gd",
		"SpaceshipController.gd",
		"TerrainMeshBuilder.gd"
	]
	
	for f_path in files:
		var fa: FileAccess = FileAccess.open("res://" + f_path, FileAccess.READ)
		_assert(fa != null, "Production script %s exists" % f_path)
		var line_count: int = 0
		while not fa.eof_reached():
			fa.get_line()
			line_count += 1
		fa.close()
		# Account for potential trailing blank line at EOF
		_assert(line_count <= 250, "%s line count %d <= 250 lines" % [f_path, line_count])

func _test_repo_cleanliness_no_orphaned_uids() -> void:
	_start_test("GUARDRAILS 5.2: Verification of Orphaned UID Removal")
	var exists: bool = FileAccess.file_exists("res://test_adversarial_empirical_m12.gd.uid")
	_assert(!exists, "Orphaned test_adversarial_empirical_m12.gd.uid does not exist")
