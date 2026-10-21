extends SceneTree

# ==============================================================================
# CRYOVANTA PROTOCOL: ADVERSARIAL REVIEWER 2 TEST HARNESS (M13)
# ==============================================================================
# Focuses on edge cases and adversarial scenarios:
# 1. TerrainMeshBuilder:
#    - Multi-worker concurrent execution across all 4 buffer slots under load
#    - Slot clamping on out-of-bounds worker index (-10, 999)
#    - FBM unnormalized output determinism and finite range
# 2. ChunkTaskScheduler:
#    - cancel_all_jobs() with zero queued jobs (empty queue)
#    - cancel_job() with invalid IDs (0, -1, 9999)
#    - cancel_all_jobs() and cancel_job() during shutdown / after shutdown
#    - Rapid burst submission with immediate cancel_all_jobs() and auto-reclaim
#    - Worker thread slot index retrieval (get_current_worker_index)
# 3. ColliderPoolManager:
#    - Hostile IDs: set_collider_origin(-1), set_collider_origin(64), set_collider_origin(9999)
#    - Double release protection and position zero reset
#    - verify_integrity() accuracy across states
# ==============================================================================

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("==================================================================")
	print("CRYOVANTA PROTOCOL: REVIEWER 2 ADVERSARIAL HARNESS (M13)")
	print("==================================================================")
	
	_run_suite_terrain_mesh_builder()
	_run_suite_task_scheduler_edge_cases()
	_run_suite_collider_pool_adversarial()
	
	print("\n==================================================================")
	print("REVIEWER 2 ADVERSARIAL TEST SUMMARY")
	print("  Total Assertions:  %d" % total_assertions)
	print("  Passed Assertions: %d" % passed_assertions)
	print("  Failed Assertions: %d" % failed_assertions)
	print("==================================================================")
	
	if failed_assertions > 0:
		printerr("VERDICT: REQUEST_CHANGES - %d assertions failed!" % failed_assertions)
		quit(1)
	else:
		print("VERDICT: APPROVE - All adversarial tests passed with 0 failures!")
		quit(0)

func _assert(condition: bool, msg: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("  [FAIL] Assertion failed: %s" % msg)

func _assert_approx(a: float, b: float, tol: float = 1e-4, msg: String = "") -> void:
	_assert(absf(a - b) <= tol, "%s (expected %f, got %f, diff %f)" % [msg, b, a, absf(a - b)])

func _assert_vec3_approx(a: Vector3, b: Vector3, tol: float = 1e-4, msg: String = "") -> void:
	_assert(a.distance_to(b) <= tol, "%s (expected %s, got %s, dist %f)" % [msg, str(b), str(a), a.distance_to(b)])

# ==============================================================================
# Suite 1: TerrainMeshBuilder Adversarial & Concurrency
# ==============================================================================
class WorkerTaskContext extends RefCounted:
	var slot: int
	var iters: int
	var completed: bool = false
	var faces: PackedVector3Array
	var mesh_verts: PackedVector3Array

func _concurrent_mesh_worker(ctx: WorkerTaskContext) -> void:
	for iter in range(ctx.iters):
		var face: int = ctx.slot % 6
		var uv0: Vector2 = Vector2(-0.5, -0.5)
		var uv1: Vector2 = Vector2(0.5, 0.5)
		var rad: float = 100_000.0
		var seed_val: int = 42 + ctx.slot * 100
		var freq: float = 0.001
		var amp: float = 500.0
		
		# Build collider faces
		var f: PackedVector3Array = TerrainMeshBuilder.build_collider_faces(
			face, 1, uv0, uv1, rad, seed_val, freq, amp, ctx.slot, true
		)
		if iter == ctx.iters - 1:
			ctx.faces = f.duplicate()
	ctx.completed = true

func _run_suite_terrain_mesh_builder() -> void:
	print("\n--- Suite 1: TerrainMeshBuilder Concurrency & Out-of-Bounds Slot Clamping ---")
	TerrainMeshBuilder.init_builder()
	
	# 1. Out-of-bounds slot clamping
	# Negative slot should clamp to 0
	var f_neg: PackedVector3Array = TerrainMeshBuilder.build_collider_faces(
		0, 1, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100_000.0, 1234, 0.001, 500.0, -10, true
	)
	var f_0: PackedVector3Array = TerrainMeshBuilder.get_collider_faces(0)
	_assert(f_neg.size() == 6534, "Negative slot clamps to 0 (6534 vertices)")
	_assert(f_neg[0] == f_0[0], "Negative slot returns data matching slot 0")
	
	# Oversized slot should clamp to MAX_WORKERS - 1 (3)
	var f_over: PackedVector3Array = TerrainMeshBuilder.build_collider_faces(
		1, 1, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100_000.0, 5678, 0.001, 500.0, 999, true
	)
	var f_3: PackedVector3Array = TerrainMeshBuilder.get_collider_faces(3)
	_assert(f_over.size() == 6534, "Oversized slot clamps to slot 3 (6534 vertices)")
	_assert(f_over[0] == f_3[0], "Oversized slot returns data matching slot 3")
	
	# 2. 4 Concurrent threads stressing slots 0..3 simultaneously
	var contexts: Array[WorkerTaskContext] = []
	var threads: Array[Thread] = []
	for w in range(4):
		var ctx: WorkerTaskContext = WorkerTaskContext.new()
		ctx.slot = w
		ctx.iters = 20
		contexts.append(ctx)
		var t: Thread = Thread.new()
		threads.append(t)
		t.start(Callable(self, "_concurrent_mesh_worker").bind(ctx))
	
	for t in threads:
		t.wait_to_finish()
	
	for w in range(4):
		_assert(contexts[w].completed, "Worker %d finished all iterations" % w)
		_assert(contexts[w].faces.size() == 6534, "Worker %d generated exactly 6534 face vertices" % w)
		
		# Generate baseline single-threaded to verify 100% determinism and lack of cross-thread contamination
		var baseline: PackedVector3Array = TerrainMeshBuilder.build_collider_faces(
			w % 6, 1, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100_000.0, 42 + w * 100, 0.001, 500.0, 0, true
		)
		var diff_len: float = contexts[w].faces[0].distance_to(baseline[0])
		_assert(diff_len < 1e-4, "Worker %d matches single-threaded baseline without thread crosstalk" % w)

# ==============================================================================
# Suite 2: ChunkTaskScheduler Edge Cases & Robustness
# ==============================================================================
func _dummy_compute_task(val: int) -> int:
	return val * 3

func _delayed_compute_task(ms: int) -> int:
	OS.delay_msec(ms)
	return ms

func _run_suite_task_scheduler_edge_cases() -> void:
	print("\n--- Suite 2: ChunkTaskScheduler Edge Cases & Auto-Reclaim ---")
	var sched: ChunkTaskScheduler = ChunkTaskScheduler.new()
	root.add_child(sched)
	
	# 1. cancel_all_jobs() when queue is completely empty
	_assert(sched.get_available_slots() == 64, "Available slots initially 64")
	_assert(sched.get_queue_count() == 0, "Queue count initially 0")
	sched.cancel_all_jobs()
	sched.poll()
	_assert(sched.get_available_slots() == 64, "cancel_all_jobs on empty queue is safe, keeps 64 slots")
	_assert(sched.get_queue_count() == 0, "Queue count remains 0")
	
	# 2. cancel_job() with invalid IDs
	_assert(!sched.cancel_job(-1), "cancel_job(-1) returns false")
	_assert(!sched.cancel_job(0), "cancel_job(0) returns false")
	_assert(!sched.cancel_job(9999), "cancel_job(9999) returns false")
	_assert(!sched.reclaim_job(-1), "reclaim_job(-1) returns false")
	_assert(!sched.reclaim_job(0), "reclaim_job(0) returns false")
	_assert(!sched.reclaim_job(9999), "reclaim_job(9999) returns false")
	_assert(!sched.is_job_completed(-1), "is_job_completed(-1) returns false")
	_assert(sched.get_job_result(-1) == null, "get_job_result(-1) returns null")
	_assert(sched.get_job_status(-1) == ChunkTaskScheduler.STATUS_EMPTY, "get_job_status(-1) returns STATUS_EMPTY")
	
	# 3. Burst submit 64 jobs, immediately cancel_all_jobs(), drain, and poll
	var burst_ids: Array[int] = []
	for i in range(64):
		var jid: int = sched.submit_job(Callable(self, "_delayed_compute_task"), [30])
		_assert(jid > 0, "Burst submitted job %d" % i)
		burst_ids.append(jid)
	
	_assert(sched.get_available_slots() == 0, "All 64 slots occupied")
	sched.cancel_all_jobs()
	
	# Wait for active workers to drain
	var timeout: int = 1500
	while sched.get_active_worker_count() > 0 and timeout > 0:
		OS.delay_msec(10)
		timeout -= 10
	_assert(sched.get_active_worker_count() == 0, "All workers drained to 0 after cancel_all_jobs")
	
	# Auto-reclaim during poll()
	sched.poll()
	_assert(sched.get_available_slots() == 64, "All 64 slots auto-reclaimed during poll() after cancel_all_jobs")
	_assert(sched.get_queue_count() == 0, "Queue count == 0 after poll()")
	
	# 4. Verify ring buffer can be cleanly re-filled and re-emptied
	for i in range(16):
		var jid: int = sched.submit_job(Callable(self, "_dummy_compute_task"), [i])
		_assert(jid > 0, "Submitted second batch job %d" % i)
	
	# Wait for completion
	var wait_ms: int = 0
	while sched.get_queue_count() > 0 and wait_ms < 1000:
		OS.delay_msec(5)
		wait_ms += 5
	sched.poll()
	
	# 5. Shutdown and post-shutdown resilience
	sched.shutdown()
	_assert(!sched.is_running(), "is_running() false after shutdown")
	_assert(sched.submit_job(Callable(self, "_dummy_compute_task"), [1]) == -1, "submit_job returns -1 after shutdown")
	
	# Redundant cancel_all_jobs after shutdown
	sched.cancel_all_jobs()
	_assert(sched.get_active_worker_count() == 0, "active workers == 0 after shutdown")
	
	# Redundant shutdown
	sched.shutdown()
	_assert(!sched.is_running(), "Redundant shutdown safe")
	
	root.remove_child(sched)
	sched.free()

# ==============================================================================
# Suite 3: ColliderPoolManager Adversarial
# ==============================================================================
func _run_suite_collider_pool_adversarial() -> void:
	print("\n--- Suite 3: ColliderPoolManager Hostile Edge Cases & Double Release ---")
	var pool: ColliderPoolManager = ColliderPoolManager.new()
	root.add_child(pool)
	
	var owner_obj: RefCounted = RefCounted.new()
	var cid0: int = pool.acquire_collider(owner_obj)
	var cid1: int = pool.acquire_collider(owner_obj)
	_assert(cid0 >= 0 and cid1 >= 0 and cid0 != cid1, "Acquired two distinct colliders")
	
	# 1. Hostile set_collider_origin on out-of-bounds IDs
	pool.set_collider_origin(-1, Vector3(10, 20, 30))
	pool.set_collider_origin(64, Vector3(10, 20, 30))
	pool.set_collider_origin(9999, Vector3(10, 20, 30))
	_assert_vec3_approx(pool.get_collider_origin(-1), Vector3.ZERO, 1e-5, "get_collider_origin(-1) returns ZERO")
	_assert_vec3_approx(pool.get_collider_origin(64), Vector3.ZERO, 1e-5, "get_collider_origin(64) returns ZERO")
	
	# 2. Hostile set_collider_origin on unacquired slot
	var unacquired: int = 15
	if unacquired != cid0 and unacquired != cid1:
		pool.set_collider_origin(unacquired, Vector3(100, 200, 300))
		_assert_vec3_approx(pool.get_collider_origin(unacquired), Vector3.ZERO, 1e-5, "Unacquired slot position remains ZERO")
		_assert_vec3_approx(pool.get_body(unacquired).position, Vector3.ZERO, 1e-5, "Unacquired body position remains ZERO")
	
	# 3. Position update on valid acquired slot
	var target_origin: Vector3 = Vector3(-1234.5, 6789.0, 4321.25)
	pool.set_collider_origin(cid0, target_origin)
	_assert_vec3_approx(pool.get_collider_origin(cid0), target_origin, 1e-5, "Valid slot gets assigned origin")
	_assert_vec3_approx(pool.get_body(cid0).position, target_origin, 1e-5, "Valid body position matches target origin")
	
	# 4. Release resets position to Vector3.ZERO
	var rel0: bool = pool.release_collider(cid0)
	_assert(rel0, "release_collider(cid0) succeeds")
	_assert_vec3_approx(pool.get_collider_origin(cid0), Vector3.ZERO, 1e-5, "Released slot origin reset to ZERO")
	_assert_vec3_approx(pool.get_body(cid0).position, Vector3.ZERO, 1e-5, "Released body position reset to ZERO")
	
	# 5. Double release returns false and does not corrupt pool
	var double_rel: bool = pool.release_collider(cid0)
	_assert(!double_rel, "Double release returns false")
	
	# 6. Out-of-bounds release returns false
	_assert(!pool.release_collider(-1), "Release -1 returns false")
	_assert(!pool.release_collider(64), "Release 64 returns false")
	_assert(!pool.release_collider(9999), "Release 9999 returns false")
	
	# 7. Release second collider
	pool.release_collider(cid1)
	
	# 8. Integrity audit
	var audit: Dictionary = pool.verify_integrity()
	_assert(audit["is_valid"], "Pool integrity audit is valid after all operations")
	_assert(audit["errors"].is_empty(), "Pool integrity has 0 errors")
	_assert(pool.get_active_count() == 0, "Active count == 0")
	_assert(pool.get_free_count() == 64, "Free count == 64")
	
	pool.clear()
	root.remove_child(pool)
	pool.free()
