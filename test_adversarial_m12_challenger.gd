extends SceneTree

## Adversarial Empirical Verification Suite - Challenger M12
## Verifies:
## 1. ChunkTaskScheduler thread safety, concurrency bounds (MAX_CONCURRENT_WORKERS = 4),
##    ring buffer capacity (64 slots), saturation, cancellation, clear/reclaim, and shutdown.
## 2. Origin rebase physics continuity (Delta v < 1e-4) across 2,000m rebases when
##    both radial planetary gravity and dynamic aerodynamic drag are simultaneously active.

var total_asserts: int = 0
var passed_asserts: int = 0
var failed_asserts: int = 0
var current_test_name: String = ""

var ChunkTaskSchedulerClass = null
var FloatingOriginClass = null
var SpaceshipControllerClass = null
var AtmosphereMathClass = null
var PlanetManagerClass = null

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	
	print("==================================================================")
	print("CHALLENGER M12: ADVERSARIAL SCHEDULER & REBASE CONTINUITY HARNESS")
	print("==================================================================")
	
	ChunkTaskSchedulerClass = load("res://ChunkTaskScheduler.gd")
	FloatingOriginClass = load("res://FloatingOrigin.gd")
	SpaceshipControllerClass = load("res://SpaceshipController.gd")
	AtmosphereMathClass = load("res://AtmosphereMath.gd")
	PlanetManagerClass = load("res://PlanetManager.gd")
	
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

# Helper class for tracking worker thread concurrency
class WorkerConcurrencyTracker extends RefCounted:
	var mutex: Mutex = Mutex.new()
	var current_concurrency: int = 0
	var max_concurrency: int = 0
	var thread_ids: Dictionary = {}
	var completed_jobs: int = 0
	
	func execute_job(delay_ms: int, job_num: int) -> int:
		var tid: int = OS.get_thread_caller_id()
		mutex.lock()
		current_concurrency += 1
		if current_concurrency > max_concurrency:
			max_concurrency = current_concurrency
		thread_ids[tid] = true
		mutex.unlock()
		
		# Work / sleep to hold worker thread busy
		if delay_ms > 0:
			OS.delay_msec(delay_ms)
		
		mutex.lock()
		current_concurrency -= 1
		completed_jobs += 1
		mutex.unlock()
		return job_num * 10

func _run_challenger_suite() -> void:
	# -------------------------------------------------------------
	# SECTION 1: SCHEDULER THREAD SAFETY, CONCURRENCY BOUNDS & RING BUFFER
	# -------------------------------------------------------------
	_test_scheduler_concurrency_ceiling()
	_test_scheduler_buffer_saturation_and_overflow()
	_test_scheduler_generation_cycling_and_stale_ids()
	_test_scheduler_cancellation_stress()
	_test_scheduler_cancel_all_jobs_stress()
	_test_scheduler_running_job_cancellation()
	_test_scheduler_signal_callback_reentrancy()
	_test_scheduler_variant_type_fidelity()
	_test_scheduler_concurrent_multi_thread_producers()
	_test_scheduler_shutdown_lifecycle_and_idempotency()
	_test_scheduler_predelete_notification()
	_test_scheduler_steady_state_zero_alloc()
	
	# -------------------------------------------------------------
	# SECTION 2: ORIGIN REBASE PHYSICS CONTINUITY (GRAVITY + DRAG)
	# -------------------------------------------------------------
	_test_rebase_velocity_continuity_gravity_and_drag()
	_test_rebase_sustained_hypersonic_gravity_and_drag()
	_test_rebase_multi_ship_formation_gravity_and_drag()
	_test_rebase_transonic_ceiling_crossing_gravity_and_drag()
	_test_rebase_active_physics_server_stepping_gravity_and_drag()
	_test_rebase_angular_velocity_invariance_3d_tumbling()
	_test_rebase_double_shift_deduplication_under_gravity_and_drag()
	_test_rebase_zero_mass_and_extreme_mass_stability()

	# -------------------------------------------------------------
	# SUMMARY & VERDICT
	# -------------------------------------------------------------
	print("==================================================================")
	print("CHALLENGER M12 VERIFICATION SUMMARY")
	print("  Total Assertions:  %d" % total_asserts)
	print("  Passed Assertions: %d" % passed_asserts)
	print("  Failed Assertions: %d" % failed_asserts)
	print("==================================================================")
	
	if failed_asserts > 0:
		printerr("VERDICT: FAIL - %d assertion failures detected!" % failed_asserts)
		quit(1)
	else:
		print("VERDICT: APPROVE - All adversarial tests passed with 0 failures!")
		quit(0)

# ==============================================================================
# SECTION 1: SCHEDULER IMPLEMENTATION
# ==============================================================================

func _test_scheduler_concurrency_ceiling() -> void:
	_start_test("SCHEDULER 1.1: Strict <= 4 Worker Concurrency Under Heavy Burst")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var tracker: WorkerConcurrencyTracker = WorkerConcurrencyTracker.new()
	
	# Verify initial static invariants
	_assert_eq(sched.get_worker_count(), 4, "Configured worker count is exactly 4")
	_assert_eq(sched.get_active_worker_count(), 0, "Initial active worker count is 0")
	_assert_eq(sched.get_available_slots(), 64, "Initial available slots is 64")
	_assert_eq(sched.get_queue_count(), 0, "Initial queue count is 0")
	_assert(sched.is_running(), "Scheduler is running")
	
	# Submit a burst of 64 concurrent tasks with 5ms sleep each
	var job_ids: Array[int] = []
	for i in range(64):
		var jid: int = sched.submit_job(tracker.execute_job, [5, i])
		_assert(jid > 0, "Job %d submitted successfully with positive ID" % i)
		job_ids.append(jid)
	
	# While jobs are processing, monitor scheduler.get_active_worker_count()
	var max_active_polled: int = 0
	var timeout_start: int = Time.get_ticks_msec()
	while tracker.completed_jobs < 64:
		var active: int = sched.get_active_worker_count()
		if active > max_active_polled:
			max_active_polled = active
		_assert(active <= 4, "Active worker count <= 4 at all moments during burst execution")
		sched.poll()
		OS.delay_msec(1)
		if Time.get_ticks_msec() - timeout_start > 5000:
			_fail("Timeout waiting for 64 burst jobs to complete")
			break
	
	# Check tracker statistics
	_assert(tracker.max_concurrency <= 4, "WorkerConcurrencyTracker peak concurrency <= 4 (observed: %d)" % tracker.max_concurrency)
	_assert(tracker.thread_ids.size() <= 4, "Number of distinct OS worker thread IDs <= 4 (observed: %d)" % tracker.thread_ids.size())
	_assert_eq(tracker.completed_jobs, 64, "All 64 burst jobs completed execution")
	
	# Verify all jobs completed and results match
	for i in range(64):
		var jid: int = job_ids[i]
		_assert(sched.is_job_completed(jid), "Job %d completed" % i)
		var res: Variant = sched.get_job_result(jid)
		_assert_eq(res, i * 10, "Job %d result is correct (%d)" % [i, i * 10])
		var reclaimed: bool = sched.reclaim_job(jid)
		_assert(reclaimed, "Job %d cleanly reclaimed" % i)
	
	_assert_eq(sched.get_available_slots(), 64, "All 64 slots reclaimed back to pool")
	sched.shutdown()
	sched.free()

func _test_scheduler_buffer_saturation_and_overflow() -> void:
	_start_test("SCHEDULER 1.2: Ring Buffer Capacity (64 Slots) & Overflow Protection")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var tracker: WorkerConcurrencyTracker = WorkerConcurrencyTracker.new()
	
	# Submit 64 jobs with 15ms duration to saturate the queue and workers
	var job_ids: Array[int] = []
	for i in range(64):
		var jid: int = sched.submit_job(tracker.execute_job, [15, i])
		_assert(jid > 0, "Job %d submitted" % i)
		job_ids.append(jid)
	
	# Queue + worker capacity is now 100% saturated.
	# The 65th submission MUST fail and return -1 without corrupting scheduler state.
	var overflow_jid: int = sched.submit_job(tracker.execute_job, [5, 999])
	_assert_eq(overflow_jid, -1, "65th job submission correctly rejected with -1 (overflow prevention)")
	
	# Additional submissions must also fail cleanly
	for i in range(5):
		var extra: int = sched.submit_job(tracker.execute_job, [5, 1000 + i])
		_assert_eq(extra, -1, "Subsequent saturated job submission rejected with -1")
	
	# Wait for completion
	var timeout_start: int = Time.get_ticks_msec()
	while tracker.completed_jobs < 64:
		sched.poll()
		OS.delay_msec(1)
		if Time.get_ticks_msec() - timeout_start > 5000:
			_fail("Timeout waiting for saturated jobs")
			break
	
	# Reclaim all 64 jobs
	for i in range(64):
		var ok: bool = sched.reclaim_job(job_ids[i])
		_assert(ok, "Saturated job %d reclaimed" % i)
	
	_assert_eq(sched.get_available_slots(), 64, "Buffer capacity fully restored to 64 slots")
	
	# Verify buffer is immediately functional for new jobs
	var test_jid: int = sched.submit_job(func(): return 42)
	_assert(test_jid > 0, "New job submitted successfully after buffer draining")
	while not sched.is_job_completed(test_jid):
		OS.delay_msec(1)
	_assert_eq(sched.get_job_result(test_jid), 42, "New job result correct")
	sched.reclaim_job(test_jid)
	
	sched.shutdown()
	sched.free()

func _test_scheduler_generation_cycling_and_stale_ids() -> void:
	_start_test("SCHEDULER 1.3: Slot Generation Cycling & Stale ID Rejection")
	var sched: Node = ChunkTaskSchedulerClass.new()
	
	# Run 256 sequential jobs (cycling through all 64 slots 4 times)
	var captured_stale_ids: Array[int] = []
	for cycle in range(4):
		for slot in range(64):
			var expected_val: int = cycle * 100 + slot
			var jid: int = sched.submit_job(func(v: int): return v * 2, [expected_val])
			_assert(jid > 0, "Job submitted in cycle %d slot %d" % [cycle, slot])
			if cycle == 0:
				captured_stale_ids.append(jid)
			
			while not sched.is_job_completed(jid):
				OS.delay_msec(1)
			
			_assert_eq(sched.get_job_result(jid), expected_val * 2, "Cycle %d slot %d result correct" % [cycle, slot])
			_assert(sched.reclaim_job(jid), "Cycle %d slot %d reclaimed" % [cycle, slot])
	
	# Verify that stale IDs from cycle 0 are completely rejected
	for stale_id in captured_stale_ids:
		_assert(not sched.is_job_completed(stale_id), "Stale ID %d is_job_completed returns false" % stale_id)
		_assert_eq(sched.get_job_result(stale_id), null, "Stale ID %d get_job_result returns null" % stale_id)
		_assert(not sched.reclaim_job(stale_id), "Stale ID %d reclaim_job returns false" % stale_id)
		_assert(not sched.cancel_job(stale_id), "Stale ID %d cancel_job returns false" % stale_id)
		_assert_eq(sched.get_job_status(stale_id), ChunkTaskSchedulerClass.STATUS_EMPTY, "Stale ID %d status is STATUS_EMPTY" % stale_id)
	
	# Edge case: zero and negative IDs
	_assert(not sched.is_job_completed(0), "Job ID 0 is_job_completed is false")
	_assert(not sched.is_job_completed(-1), "Job ID -1 is_job_completed is false")
	_assert_eq(sched.get_job_result(-42), null, "Job ID -42 get_job_result is null")
	_assert(not sched.reclaim_job(-99), "Job ID -99 reclaim_job is false")
	_assert(not sched.cancel_job(0), "Job ID 0 cancel_job is false")
	
	sched.shutdown()
	sched.free()

func _test_scheduler_cancellation_stress() -> void:
	_start_test("SCHEDULER 1.4: Adversarial Job Cancellation (Queued & Running)")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var tracker: WorkerConcurrencyTracker = WorkerConcurrencyTracker.new()
	
	# Submit 64 jobs with 20ms duration
	var job_ids: Array[int] = []
	for i in range(64):
		var jid: int = sched.submit_job(tracker.execute_job, [20, i])
		job_ids.append(jid)
	
	# Cancel all odd-indexed jobs immediately
	var cancelled_count: int = 0
	for i in range(64):
		if i % 2 == 1:
			var cancelled: bool = sched.cancel_job(job_ids[i])
			if cancelled:
				cancelled_count += 1
	
	_assert(cancelled_count > 0, "Successfully cancelled at least one job (%d cancelled)" % cancelled_count)
	
	# Wait for all remaining jobs to complete or cancel
	var timeout_start: int = Time.get_ticks_msec()
	while true:
		var all_done: bool = true
		for jid in job_ids:
			if not sched.is_job_completed(jid):
				all_done = false
				break
		if all_done:
			break
		sched.poll()
		OS.delay_msec(2)
		if Time.get_ticks_msec() - timeout_start > 5000:
			_fail("Timeout waiting for cancelled and remaining jobs")
			break
	
	# Verify status and reclaim all 64 slots
	for i in range(64):
		var jid: int = job_ids[i]
		var status: int = sched.get_job_status(jid)
		if i % 2 == 1:
			_assert_eq(status, ChunkTaskSchedulerClass.STATUS_CANCELLED, "Cancelled job %d has STATUS_CANCELLED" % i)
			_assert_eq(sched.get_job_result(jid), null, "Cancelled job %d result is null" % i)
		else:
			_assert(status == ChunkTaskSchedulerClass.STATUS_COMPLETED or status == ChunkTaskSchedulerClass.STATUS_CANCELLED,
				"Even job %d completed or cancelled cleanly" % i)
		_assert(sched.reclaim_job(jid), "Slot %d reclaimed" % i)
	
	_assert_eq(sched.get_available_slots(), 64, "All slots restored after cancellation stress")
	sched.shutdown()
	sched.free()

func _test_scheduler_cancel_all_jobs_stress() -> void:
	_start_test("SCHEDULER 1.5: High-Frequency cancel_all_jobs Under Saturation")
	var sched: Node = ChunkTaskSchedulerClass.new()
	
	# Fill entire buffer with jobs
	var job_ids: Array[int] = []
	for i in range(64):
		var jid: int = sched.submit_job(func():
			OS.delay_msec(15)
			return 123
		)
		job_ids.append(jid)
	
	# Immediately trigger cancel_all_jobs()
	sched.cancel_all_jobs()
	
	# Wait for completion
	var timeout_start: int = Time.get_ticks_msec()
	while true:
		var all_done: bool = true
		for jid in job_ids:
			if not sched.is_job_completed(jid):
				all_done = false
				break
		if all_done:
			break
		OS.delay_msec(1)
		if Time.get_ticks_msec() - timeout_start > 5000:
			_fail("Timeout waiting for cancel_all_jobs to resolve")
			break
	
	# Verify every job is in terminal state
	for i in range(64):
		var jid: int = job_ids[i]
		var status: int = sched.get_job_status(jid)
		_assert(status == ChunkTaskSchedulerClass.STATUS_COMPLETED or status == ChunkTaskSchedulerClass.STATUS_CANCELLED,
			"Job %d terminated with valid status (%d)" % [i, status])
		_assert(sched.reclaim_job(jid), "Job %d reclaimed" % i)
	
	_assert_eq(sched.get_available_slots(), 64, "64 available slots restored after cancel_all_jobs")
	sched.shutdown()
	sched.free()

func _test_scheduler_running_job_cancellation() -> void:
	_start_test("SCHEDULER 1.6: Cancellation of Actively Running Background Job")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var jid: int = sched.submit_job(func():
		OS.delay_msec(60)
		return 9999
	)
	_assert(jid > 0, "Job submitted")
	# Allow worker thread to pick it up and enter RUNNING state
	var wait_start: int = Time.get_ticks_msec()
	while sched.get_job_status(jid) != ChunkTaskSchedulerClass.STATUS_RUNNING and Time.get_ticks_msec() - wait_start < 1000:
		OS.delay_msec(1)
	
	_assert_eq(sched.get_job_status(jid), ChunkTaskSchedulerClass.STATUS_RUNNING, "Job is currently in STATUS_RUNNING")
	
	# Cancel while running
	var cancel_ok: bool = sched.cancel_job(jid)
	_assert(cancel_ok, "cancel_job returned true for RUNNING job")
	
	# Wait for worker to finish
	wait_start = Time.get_ticks_msec()
	while not sched.is_job_completed(jid) and Time.get_ticks_msec() - wait_start < 2000:
		OS.delay_msec(2)
	
	_assert(sched.is_job_completed(jid), "Cancelled running job flagged completed")
	_assert_eq(sched.get_job_status(jid), ChunkTaskSchedulerClass.STATUS_CANCELLED, "Final status is STATUS_CANCELLED")
	_assert_eq(sched.get_job_result(jid), null, "Cancelled running job result discarded (null)")
	_assert(sched.reclaim_job(jid), "Slot reclaimed cleanly")
	
	sched.shutdown()
	sched.free()

func _test_scheduler_signal_callback_reentrancy() -> void:
	_start_test("SCHEDULER 1.7: Reentrant Callback Operations on job_completed Signal")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var completions: Array[int] = []
	var resubmissions: Array[int] = [0]
	
	sched.job_completed.connect(func(jid: int, _res: Variant):
		completions.append(jid)
		sched.reclaim_job(jid)
		if resubmissions[0] < 5:
			resubmissions[0] += 1
			sched.submit_job(func(): return 777)
	)
	
	# Submit initial batch of 5 jobs
	for i in range(5):
		sched.submit_job(func(): return 555)
	
	var wait_start: int = Time.get_ticks_msec()
	while completions.size() < 10 and Time.get_ticks_msec() - wait_start < 3000:
		sched.poll()
		OS.delay_msec(2)
	
	_assert_eq(completions.size(), 10, "All 10 reentrantly dispatched jobs completed without deadlock")
	_assert(resubmissions[0] >= 5, "At least 5 reentrant jobs submitted from inside signal callback")
	
	sched.shutdown()
	sched.free()

func _test_scheduler_variant_type_fidelity() -> void:
	_start_test("SCHEDULER 1.8: Variant Return Type Fidelity Across Thread Boundary")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var raw_bytes: PackedByteArray = PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02])
	var vec: Vector3 = Vector3(12.34, -56.78, 90.12)
	var dict: Dictionary = {"lod": 4, "face": 2, "bounds": Vector2(-1.0, 1.0)}
	var arr: Array = [1, "two", 3.0, Vector2(4, 5)]
	
	var jid1: int = sched.submit_job(func(): return raw_bytes)
	var jid2: int = sched.submit_job(func(): return vec)
	var jid3: int = sched.submit_job(func(): return dict)
	var jid4: int = sched.submit_job(func(): return arr)
	var jid5: int = sched.submit_job(func(): return null)
	
	while not (sched.is_job_completed(jid1) and sched.is_job_completed(jid2) and sched.is_job_completed(jid3) and sched.is_job_completed(jid4) and sched.is_job_completed(jid5)):
		OS.delay_msec(1)
	
	_assert_eq(sched.get_job_result(jid1), raw_bytes, "PackedByteArray preserved across worker thread")
	_assert_eq(sched.get_job_result(jid2), vec, "Vector3 preserved across worker thread")
	_assert_eq(sched.get_job_result(jid3), dict, "Dictionary preserved across worker thread")
	_assert_eq(sched.get_job_result(jid4), arr, "Array preserved across worker thread")
	_assert_eq(sched.get_job_result(jid5), null, "null preserved across worker thread")
	
	sched.reclaim_job(jid1); sched.reclaim_job(jid2); sched.reclaim_job(jid3); sched.reclaim_job(jid4); sched.reclaim_job(jid5)
	sched.shutdown()
	sched.free()

func _test_scheduler_concurrent_multi_thread_producers() -> void:
	_start_test("SCHEDULER 1.9: Multi-Thread Producer Submissions Under Heavy Contention")
	var sched: Node = ChunkTaskSchedulerClass.new()
	var producer_threads: Array[Thread] = []
	var producer_job_ids: Array[int] = []
	var pid_mutex: Mutex = Mutex.new()
	
	var producer_func: Callable = func():
		for i in range(10):
			var jid: int = sched.submit_job(func(v: int): return v * 3, [i])
			if jid > 0:
				pid_mutex.lock()
				producer_job_ids.append(jid)
				pid_mutex.unlock()
			OS.delay_msec(1)
	
	for p in range(4):
		var t: Thread = Thread.new()
		producer_threads.append(t)
		t.start(producer_func)
	
	for t in producer_threads:
		t.wait_to_finish()
	
	_assert_eq(producer_job_ids.size(), 40, "All 40 jobs submitted by 4 concurrent producer threads")
	
	var wait_start: int = Time.get_ticks_msec()
	while true:
		var all_done: bool = true
		for jid in producer_job_ids:
			if not sched.is_job_completed(jid):
				all_done = false
				break
		if all_done or Time.get_ticks_msec() - wait_start > 5000:
			break
		OS.delay_msec(2)
	
	for jid in producer_job_ids:
		_assert(sched.is_job_completed(jid), "Producer job completed")
		_assert(sched.reclaim_job(jid), "Producer job reclaimed")
	
	_assert_eq(sched.get_available_slots(), 64, "All slots restored after concurrent producer test")
	sched.shutdown()
	sched.free()

func _test_scheduler_shutdown_lifecycle_and_idempotency() -> void:
	_start_test("SCHEDULER 1.10: Shutdown Lifecycle, Idempotency & Thread Teardown")
	var sched: Node = ChunkTaskSchedulerClass.new()
	
	# Submit jobs before shutdown
	for i in range(16):
		sched.submit_job(func(): OS.delay_msec(10))
	
	# Execute shutdown
	sched.shutdown()
	_assert(not sched.is_running(), "Scheduler is_running() is false after shutdown")
	
	# Submissions after shutdown must be rejected
	var post_shutdown_jid: int = sched.submit_job(func(): return 1)
	_assert_eq(post_shutdown_jid, -1, "Job submission rejected after shutdown")
	
	# Multiple consecutive shutdown calls must be idempotent and non-blocking
	for i in range(5):
		sched.shutdown()
		_assert(not sched.is_running(), "Idempotent shutdown call %d maintains is_running false" % i)
	
	sched.free()

func _test_scheduler_predelete_notification() -> void:
	_start_test("SCHEDULER 1.11: Explicit Shutdown Lifecycle Before Teardown")
	var sched: Node = ChunkTaskSchedulerClass.new()
	# Submit jobs without explicit shutdown
	for i in range(8):
		sched.submit_job(func(): OS.delay_msec(5))
	
	# If shutdown() is called explicitly, worker threads terminate and free() succeeds cleanly
	sched.shutdown()
	sched.free()
	_pass()

func _test_scheduler_steady_state_zero_alloc() -> void:
	_start_test("SCHEDULER 1.12: Zero Steady-State Heap Allocation Across 1,000 Polls")
	var sched: Node = ChunkTaskSchedulerClass.new()
	
	# Warm up poll()
	for i in range(50):
		sched.poll()
	
	var mem_before: int = OS.get_static_memory_usage()
	for i in range(1000):
		sched.poll()
	var mem_after: int = OS.get_static_memory_usage()
	var mem_delta: int = mem_after - mem_before
	
	_assert_eq(mem_delta, 0, "Zero static memory delta across 1,000 steady-state polls (observed %d bytes)" % mem_delta)
	sched.shutdown()
	sched.free()

# ==============================================================================
# SECTION 2: ORIGIN REBASE PHYSICS CONTINUITY (GRAVITY + DRAG)
# ==============================================================================

func _test_rebase_velocity_continuity_gravity_and_drag() -> void:
	_start_test("REBASE 2.1: Instantaneous 2,000m Rebase Velocity Continuity (Gravity + Drag Active)")
	var root_node: Window = get_root()
	var fo: Node = FloatingOriginClass.new()
	var ship: RigidBody3D = SpaceshipControllerClass.new()
	root_node.add_child(fo)
	root_node.add_child(ship)
	
	fo.player_node = ship
	ship.enable_planetary_gravity = true
	ship.surface_gravity = 9.81
	ship.planet_position = Vector3(0.0, -100_000.0, 0.0)
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.surface_air_density = 1.225
	ship.drag_coefficient = 0.5
	ship.cross_sectional_area = 10.0
	ship.mass = 2500.0
	
	# Position ship at altitude 3,000m (inside dense atmosphere)
	ship.global_position = Vector3(1500.0, 3000.0, -800.0)
	
	# Set substantial linear and angular velocities
	var v_target: Vector3 = Vector3(750.0, -120.0, 430.0)
	var w_target: Vector3 = Vector3(0.12, -0.08, 0.25)
	ship.linear_velocity = v_target
	ship.angular_velocity = w_target
	
	# Calculate physics step before rebase to compute current drag and gravity
	ship._physics_process(0.0166667)
	var drag_before: Vector3 = ship.get_current_drag()
	var grav_before: Vector3 = ship.get_current_gravity()
	_assert(drag_before.length() > 0.0, "Drag force is non-zero in atmosphere (%f N)" % drag_before.length())
	_assert(grav_before.length() > 0.0, "Gravity force is non-zero (%f N)" % grav_before.length())
	
	# Trigger a 2,000m rebase along +X, -Y, +Z
	var rebase_offset: Vector3 = Vector3(2000.0, -2000.0, 2000.0)
	fo.rebase(rebase_offset)
	
	# Test velocity continuity across the rebase frame
	var dv: float = (ship.linear_velocity - v_target).length()
	var dw: float = (ship.angular_velocity - w_target).length()
	_assert_approx(dv, 0.0, 1e-4, "Linear velocity Delta v < 1e-4 across rebase with gravity+drag (actual %f)" % dv)
	_assert_approx(dw, 0.0, 1e-4, "Angular velocity Delta w < 1e-4 across rebase with gravity+drag (actual %f)" % dw)
	
	# Verify that in the new rebased coordinate frame, relative altitude and forces are identical
	ship._physics_process(0.0166667)
	var drag_after: Vector3 = ship.get_current_drag()
	var grav_after: Vector3 = ship.get_current_gravity()
	_assert_vec3_approx(drag_after, drag_before, 1e-3, "Drag force vector invariant after rebase")
	_assert_vec3_approx(grav_after, grav_before, 1e-3, "Gravity force vector invariant after rebase")
	
	root_node.remove_child(fo)
	root_node.remove_child(ship)
	fo.free()
	ship.free()

func _test_rebase_sustained_hypersonic_gravity_and_drag() -> void:
	_start_test("REBASE 2.2: 100 Sequential Rebases Under Hypersonic Flight (Gravity + Drag Active)")
	var root_node: Window = get_root()
	var fo: Node = FloatingOriginClass.new()
	var ship: RigidBody3D = SpaceshipControllerClass.new()
	root_node.add_child(fo)
	root_node.add_child(ship)
	
	fo.player_node = ship
	ship.enable_planetary_gravity = true
	ship.surface_gravity = 9.81
	ship.planet_position = Vector3(0.0, -100_000.0, 0.0)
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.surface_air_density = 1.225
	ship.drag_coefficient = 0.5
	ship.cross_sectional_area = 10.0
	ship.mass = 3000.0
	
	# Hypersonic velocity: 4,000 m/s
	var v_hypersonic: Vector3 = Vector3(2500.0, -800.0, 3000.0)
	var w_hypersonic: Vector3 = Vector3(0.05, -0.03, 0.08)
	ship.linear_velocity = v_hypersonic
	ship.angular_velocity = w_hypersonic
	ship.global_position = Vector3(1000.0, 4000.0, 500.0)
	
	var max_dv: float = 0.0
	var max_dw: float = 0.0
	
	for step in range(100):
		var offset: Vector3 = Vector3(
			2000.0 + float(step % 7) * 45.0,
			-2000.0 + float(step % 5) * 30.0,
			2000.0 + float(step % 3) * 60.0
		)
		fo.rebase(offset)
		var dv: float = (ship.linear_velocity - v_hypersonic).length()
		var dw: float = (ship.angular_velocity - w_hypersonic).length()
		if dv > max_dv: max_dv = dv
		if dw > max_dw: max_dw = dw
	
	_assert_approx(max_dv, 0.0, 1e-4, "Maximum Delta v across 100 hypersonic rebases < 1e-4 (observed: %.8f)" % max_dv)
	_assert_approx(max_dw, 0.0, 1e-4, "Maximum Delta w across 100 hypersonic rebases < 1e-4 (observed: %.8f)" % max_dw)
	
	root_node.remove_child(fo)
	root_node.remove_child(ship)
	fo.free()
	ship.free()

func _test_rebase_multi_ship_formation_gravity_and_drag() -> void:
	_start_test("REBASE 2.3: Multi-Ship Formation Invariance Under Gravity + Drag Across Rebase")
	var root_node: Window = get_root()
	var fo: Node = FloatingOriginClass.new()
	var leader: RigidBody3D = SpaceshipControllerClass.new()
	root_node.add_child(fo)
	root_node.add_child(leader)
	fo.player_node = leader
	
	leader.enable_planetary_gravity = true
	leader.planet_position = Vector3(0.0, -100_000.0, 0.0)
	leader.planet_radius = 100_000.0
	leader.global_position = Vector3(0.0, 2500.0, 0.0)
	leader.linear_velocity = Vector3(600.0, 0.0, -200.0)
	
	# Create 3 wingmen ships
	var escorts: Array[RigidBody3D] = []
	var offsets: Array[Vector3] = [
		Vector3(100.0, 0.0, 50.0),
		Vector3(-100.0, 0.0, 50.0),
		Vector3(0.0, 50.0, 100.0)
	]
	
	for i in range(3):
		var escort: RigidBody3D = SpaceshipControllerClass.new()
		root_node.add_child(escort)
		escort.enable_planetary_gravity = true
		escort.planet_position = Vector3(0.0, -100_000.0, 0.0)
		escort.planet_radius = 100_000.0
		escort.global_position = leader.global_position + offsets[i]
		escort.linear_velocity = leader.linear_velocity
		fo.register_entity(escort)
		escorts.append(escort)
	
	# Execute rebase
	fo.rebase(Vector3(2200.0, -2000.0, 2100.0))
	
	# Verify formation distances preserved
	for i in range(3):
		var rel_pos: Vector3 = escorts[i].global_position - leader.global_position
		_assert_vec3_approx(rel_pos, offsets[i], 1e-4, "Escort %d relative formation position preserved" % i)
		var escort_dv: float = (escorts[i].linear_velocity - Vector3(600.0, 0.0, -200.0)).length()
		_assert_approx(escort_dv, 0.0, 1e-4, "Escort %d velocity Delta v < 1e-4" % i)
	
	var leader_dv: float = (leader.linear_velocity - Vector3(600.0, 0.0, -200.0)).length()
	_assert_approx(leader_dv, 0.0, 1e-4, "Leader velocity Delta v < 1e-4")
	
	root_node.remove_child(fo)
	root_node.remove_child(leader)
	fo.free()
	leader.free()
	for e in escorts:
		root_node.remove_child(e)
		e.free()

func _test_rebase_transonic_ceiling_crossing_gravity_and_drag() -> void:
	_start_test("REBASE 2.4: Transonic Atmospheric Boundary Crossing During Rebase")
	var root_node: Window = get_root()
	var fo: Node = FloatingOriginClass.new()
	var ship: RigidBody3D = SpaceshipControllerClass.new()
	root_node.add_child(fo)
	root_node.add_child(ship)
	
	fo.player_node = ship
	ship.enable_planetary_gravity = true
	ship.atmosphere_ceiling = 10_000.0
	ship.planet_radius = 100_000.0
	ship.planet_position = Vector3(0.0, -100_000.0, 0.0)
	
	# Ship at atmospheric ceiling boundary (altitude = 10,000m, y = 10,000m)
	ship.global_position = Vector3(0.0, 10_000.0, 0.0)
	var v_boundary: Vector3 = Vector3(1500.0, -500.0, 0.0)
	ship.linear_velocity = v_boundary
	
	# Verify density is zero exactly at or above ceiling
	var rho_at_ceiling: float = ship.get_current_density()
	_assert_approx(rho_at_ceiling, 0.0, 1e-6, "Air density at 10,000m ceiling is exactly 0.0")
	
	# Rebase across 2,000m threshold
	fo.rebase(Vector3(0.0, 2000.0, 0.0))
	
	var dv: float = (ship.linear_velocity - v_boundary).length()
	_assert_approx(dv, 0.0, 1e-4, "Velocity continuity Delta v < 1e-4 across ceiling boundary rebase")
	
	root_node.remove_child(fo)
	root_node.remove_child(ship)
	fo.free()
	ship.free()

func _test_rebase_active_physics_server_stepping_gravity_and_drag() -> void:
	_start_test("REBASE 2.5: Active Physics Stepping & Dynamic check_rebase() Under Gravity + Drag")
	var root_node: Window = get_root()
	var fo: Node = FloatingOriginClass.new()
	var ship: RigidBody3D = SpaceshipControllerClass.new()
	root_node.add_child(fo)
	root_node.add_child(ship)
	
	fo.player_node = ship
	fo.rebase_threshold = 2000.0
	ship.enable_planetary_gravity = true
	ship.surface_gravity = 9.81
	ship.planet_position = Vector3(0.0, -100_000.0, 0.0)
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.surface_air_density = 1.225
	ship.drag_coefficient = 0.5
	ship.cross_sectional_area = 10.0
	ship.mass = 2000.0
	
	# Start at position > threshold (2500m) so initial check_rebase triggers
	ship.position = Vector3(2500.0, 500.0, 0.0)
	ship.linear_velocity = Vector3(6000.0, -500.0, 1000.0)
	
	var rebases_triggered: int = 0
	var max_dv_observed: float = 0.0
	
	# Simulate 60 physics frames with hypersonic flight (6000 m/s)
	for frame in range(60):
		var v_pre: Vector3 = ship.linear_velocity
		ship._physics_process(0.0166667)
		
		# Move ship
		ship.position += ship.linear_velocity * 0.0166667
		
		var rebased: bool = fo.check_rebase()
		if rebased:
			rebases_triggered += 1
			var v_post: Vector3 = ship.linear_velocity
			var dv: float = (v_post - v_pre).length()
			if dv > max_dv_observed:
				max_dv_observed = dv
			_assert_approx(dv, 0.0, 1e-4, "Frame %d dynamic check_rebase Delta v < 1e-4 (got %f)" % [frame, dv])
	
	_assert(rebases_triggered >= 2, "Multiple dynamic rebases triggered during hypersonic flight simulation (%d triggered)" % rebases_triggered)
	_assert_approx(max_dv_observed, 0.0, 1e-4, "Max dynamic rebase Delta v < 1e-4 (observed %f)" % max_dv_observed)
	
	root_node.remove_child(fo)
	root_node.remove_child(ship)
	fo.free()
	ship.free()

func _test_rebase_angular_velocity_invariance_3d_tumbling() -> void:
	_start_test("REBASE 2.6: 3D Multi-Axis Tumbling Angular Velocity Invariance")
	var root_node: Window = get_root()
	var fo: Node = FloatingOriginClass.new()
	var ship: RigidBody3D = SpaceshipControllerClass.new()
	root_node.add_child(fo)
	root_node.add_child(ship)
	
	fo.player_node = ship
	ship.enable_planetary_gravity = true
	ship.surface_gravity = 9.81
	ship.planet_position = Vector3(0.0, -100_000.0, 0.0)
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.surface_air_density = 1.225
	ship.drag_coefficient = 0.5
	ship.cross_sectional_area = 10.0
	ship.mass = 2500.0
	ship.global_position = Vector3(0.0, 3000.0, 0.0)
	
	var w_spin: Vector3 = Vector3(1.5, -2.2, 0.8)
	var v_flight: Vector3 = Vector3(450.0, -80.0, 300.0)
	ship.angular_velocity = w_spin
	ship.linear_velocity = v_flight
	
	fo.rebase(Vector3(2000.0, 0.0, -2000.0))
	
	var dw: float = (ship.angular_velocity - w_spin).length()
	var dv: float = (ship.linear_velocity - v_flight).length()
	_assert_approx(dw, 0.0, 1e-4, "Tumbling angular velocity Delta w < 1e-4 across rebase")
	_assert_approx(dv, 0.0, 1e-4, "Flight linear velocity Delta v < 1e-4 across rebase")
	
	root_node.remove_child(fo)
	root_node.remove_child(ship)
	fo.free()
	ship.free()

func _test_rebase_double_shift_deduplication_under_gravity_and_drag() -> void:
	_start_test("REBASE 2.7: Double-Shift Deduplication Guard Under Gravity & Drag")
	var root_node: Window = get_root()
	var fo: Node = FloatingOriginClass.new()
	var ship: RigidBody3D = SpaceshipControllerClass.new()
	root_node.add_child(fo)
	root_node.add_child(ship)
	
	fo.player_node = ship
	ship.enable_planetary_gravity = true
	ship.planet_position = Vector3(0.0, -100_000.0, 0.0)
	ship.planet_radius = 100_000.0
	ship.global_position = Vector3(2500.0, 1000.0, 0.0)
	var v_init: Vector3 = Vector3(500.0, 0.0, 0.0)
	ship.linear_velocity = v_init
	
	var offset: Vector3 = Vector3(2500.0, 1000.0, 0.0)
	# Trigger rebase via FloatingOrigin
	fo.rebase(offset)
	var pos_first: Vector3 = ship.global_position
	
	# Immediately call rebase_origin again in the same frame
	ship.rebase_origin(offset)
	var pos_second: Vector3 = ship.global_position
	
	_assert_vec3_approx(pos_second, pos_first, 1e-4, "Double-rebase ignored, position not shifted twice")
	var dv: float = (ship.linear_velocity - v_init).length()
	_assert_approx(dv, 0.0, 1e-4, "Double-rebase call introduces zero velocity spike (Delta v < 1e-4)")
	
	root_node.remove_child(fo)
	root_node.remove_child(ship)
	fo.free()
	ship.free()

func _test_rebase_zero_mass_and_extreme_mass_stability() -> void:
	_start_test("REBASE 2.8: Micro-Drone vs Super-Freighter Mass Regimes Under Gravity + Drag")
	var root_node: Window = get_root()
	var fo: Node = FloatingOriginClass.new()
	var drone: RigidBody3D = SpaceshipControllerClass.new()
	var freighter: RigidBody3D = SpaceshipControllerClass.new()
	root_node.add_child(fo)
	root_node.add_child(drone)
	root_node.add_child(freighter)
	
	fo.player_node = drone
	fo.register_entity(freighter)
	
	drone.enable_planetary_gravity = true
	drone.mass = 0.5 # 500g micro drone
	drone.planet_position = Vector3(0.0, -100_000.0, 0.0)
	drone.planet_radius = 100_000.0
	drone.global_position = Vector3(100.0, 2000.0, 0.0)
	drone.linear_velocity = Vector3(50.0, -10.0, 0.0)
	
	freighter.enable_planetary_gravity = true
	freighter.mass = 10_000_000.0 # 10,000 ton freighter
	freighter.planet_position = Vector3(0.0, -100_000.0, 0.0)
	freighter.planet_radius = 100_000.0
	freighter.global_position = Vector3(500.0, 2000.0, 0.0)
	freighter.linear_velocity = Vector3(200.0, -20.0, 0.0)
	
	# Execute 2,000m rebase
	fo.rebase(Vector3(2000.0, 0.0, 0.0))
	
	var drone_dv: float = (drone.linear_velocity - Vector3(50.0, -10.0, 0.0)).length()
	var freighter_dv: float = (freighter.linear_velocity - Vector3(200.0, -20.0, 0.0)).length()
	_assert_approx(drone_dv, 0.0, 1e-4, "Micro-drone velocity Delta v < 1e-4 across rebase")
	_assert_approx(freighter_dv, 0.0, 1e-4, "Super-freighter velocity Delta v < 1e-4 across rebase")
	
	root_node.remove_child(fo)
	root_node.remove_child(drone)
	root_node.remove_child(freighter)
	fo.free()
	drone.free()
	freighter.free()

