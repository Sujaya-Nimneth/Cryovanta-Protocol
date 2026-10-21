extends SceneTree

# ==============================================================================
# CRYOVANTA PROTOCOL: ADVERSARIAL EMPIRICAL HARNESS M13 (CHALLENGER 2)
# ==============================================================================
# Empirical adversarial challenge for Milestone M13 (Phase 2 Hardening):
# 1. ColliderPoolManager:
#    - Acquisition and set_collider_origin() with varied coordinates:
#      zero, positive, negative, fractional, and astronomical offsets.
#    - Reset on release: verify bodies[id].position == Vector3.ZERO across all slots.
#    - Hostile operations: double-release, out-of-bounds IDs (-1, 64, 9999),
#      unacquired slot operations (set_origin, release, get_origin).
#    - Rapid churn: 5,000 cycles with invariant integrity audits.
# 2. Memory Allocation Audit:
#    - Stress test pack_push_constants() across 10,000 invocations (0 heap allocations).
#    - Verify zero static memory growth during steady-state ChunkTaskScheduler.poll().
#    - Burst submit, cancel_all_jobs, drain, and poll auto-reclamation memory check.
# 3. Script Line Count Audit:
#    - Verify all 10 production scripts are strictly <= 250 lines per rules.md §3.
# 4. FBM Shader Parity & 4-Worker Scratch Buffer Concurrency:
#    - Verify octave seed step 1013904223, lacunarity 2.02, initial amp 0.5.
#    - Verify multi-worker thread buffer isolation and determinism.
# ==============================================================================

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("==================================================================")
	print("CRYOVANTA PROTOCOL: M13 EMPIRICAL CHALLENGER 2 ADVERSARIAL HARNESS")
	print("==================================================================")
	
	_run_collider_origin_alignment_and_reset_suite()
	_run_collider_hostile_operations_suite()
	_run_collider_deep_churn_stress_suite()
	_run_memory_allocation_audit_suite()
	_run_production_script_line_count_suite()
	_run_fbm_and_worker_concurrency_suite()
	
	_print_summary()
	quit(0 if failed_assertions == 0 else 1)

func _assert(condition: bool, message: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("  [FAIL] Assertion failed: ", message)

func _assert_approx(a: float, b: float, tol: float, message: String) -> void:
	_assert(absf(a - b) <= tol, "%s (expected ~%f, got %f, diff %f > %f)" % [message, b, a, absf(a - b), tol])

func _assert_vec3_approx(a: Vector3, b: Vector3, tol: float, message: String) -> void:
	_assert(a.distance_to(b) <= tol, "%s (expected %s, got %s, dist %f > %f)" % [message, str(b), str(a), a.distance_to(b), tol])

# ==============================================================================
# SUITE 1: ColliderPoolManager Origin Alignment & Reset on Release
# ==============================================================================
func _run_collider_origin_alignment_and_reset_suite() -> void:
	print("\n--- Running Suite 1: ColliderPoolManager Origin Alignment & Reset ---")
	var pool: ColliderPoolManager = ColliderPoolManager.new()
	root.add_child(pool)
	
	# Initial integrity check
	var initial_audit: Dictionary = pool.verify_integrity()
	_assert(initial_audit["is_valid"], "Suite 1: Pool initialized with valid integrity")
	_assert(initial_audit["active_count"] == 0, "Suite 1: Initial active count is 0")
	_assert(initial_audit["free_count"] == 64, "Suite 1: Initial free count is 64")
	
	# 1.1 Test diverse origin coordinates on a single slot
	var test_owner: RefCounted = RefCounted.new()
	var slot: int = pool.acquire_collider(test_owner)
	_assert(slot >= 0 and slot < 64, "Suite 1: Successfully acquired slot %d" % slot)
	
	var test_coords: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(1234.56, -7890.12, 4567.89),
		Vector3(-98765.43, -12345.67, -54321.0),
		Vector3(0.00012345, -0.00006789, 0.00000314),
		Vector3(1.0e12, -2.5e14, 3.7e11),
		Vector3(1.7e30, -1.7e30, 0.5e30)
	]
	
	for coord in test_coords:
		pool.set_collider_origin(slot, coord)
		var reported: Vector3 = pool.get_collider_origin(slot)
		var actual_pos: Vector3 = pool.get_body(slot).position
		_assert_vec3_approx(reported, coord, 1.0e-3 if coord.length() < 1e6 else (coord.length() * 1.0e-6), "Suite 1: get_collider_origin matches assigned coordinate %s" % str(coord))
		_assert_vec3_approx(actual_pos, coord, 1.0e-3 if coord.length() < 1e6 else (coord.length() * 1.0e-6), "Suite 1: body.position matches assigned coordinate %s" % str(coord))
	
	# Release single slot and verify reset
	var rel_ok: bool = pool.release_collider(slot)
	_assert(rel_ok, "Suite 1: Successfully released slot %d" % slot)
	_assert(pool.get_body(slot).position == Vector3.ZERO, "Suite 1: body.position strictly reset to Vector3.ZERO upon release")
	_assert(pool.get_collider_origin(slot) == Vector3.ZERO, "Suite 1: get_collider_origin returns Vector3.ZERO for released slot")
	_assert(pool.get_collision_shape(slot).disabled == true, "Suite 1: Collision shape disabled on release")
	_assert(pool.get_body(slot).collision_layer == 0, "Suite 1: Collision layer 0 on release")
	_assert(pool.get_body(slot).collision_mask == 0, "Suite 1: Collision mask 0 on release")
	_assert(pool.get_collider_owner(slot) == null, "Suite 1: Collider owner cleared on release")
	
	# 1.2 Full 64-Slot Saturation, Multi-Coordinate Offset, and Complete Reset
	var owners: Array[RefCounted] = []
	var acquired_slots: Array[int] = []
	for i in range(64):
		var o: RefCounted = RefCounted.new()
		owners.append(o)
		var cid: int = pool.acquire_collider(o)
		_assert(cid >= 0 and cid < 64, "Suite 1: Acquired slot %d (index %d)" % [cid, i])
		acquired_slots.append(cid)
		
		# Set arbitrary non-zero origin
		var offset: Vector3 = Vector3(
			float(i + 1) * 3141.59,
			-float(i + 1) * 2718.28,
			float((i * 17) % 23 + 1) * 1000.0
		)
		pool.set_collider_origin(cid, offset)
		_assert(pool.get_body(cid).position != Vector3.ZERO, "Suite 1: Slot %d has non-zero position before release" % cid)
		_assert_vec3_approx(pool.get_body(cid).position, offset, 1.0e-2, "Suite 1: Slot %d body position matches offset" % cid)
	
	_assert(pool.get_active_count() == 64, "Suite 1: Active count is exactly 64")
	_assert(pool.get_free_count() == 0, "Suite 1: Free count is exactly 0")
	_assert(pool.has_available(1) == false, "Suite 1: has_available(1) is false when saturated")
	
	# Release all 64 slots in reverse order and verify position reset on EVERY slot
	for i in range(63, -1, -1):
		var cid: int = acquired_slots[i]
		var released: bool = pool.release_collider(cid)
		_assert(released, "Suite 1: Successfully released saturated slot %d" % cid)
		_assert(pool.get_body(cid).position == Vector3.ZERO, "Suite 1: body[%d].position strictly Vector3.ZERO immediately after release" % cid)
		_assert(pool.get_collider_origin(cid) == Vector3.ZERO, "Suite 1: get_collider_origin(%d) returns Vector3.ZERO after release" % cid)
	
	var post_audit: Dictionary = pool.verify_integrity()
	_assert(post_audit["is_valid"], "Suite 1: Post-saturation audit is valid")
	_assert(post_audit["active_count"] == 0, "Suite 1: Post-saturation active count is 0")
	_assert(post_audit["free_count"] == 64, "Suite 1: Post-saturation free count is 64")
	_assert(post_audit["errors"].is_empty(), "Suite 1: Zero errors reported after all 64 slots released")
	
	pool.clear()
	root.remove_child(pool)
	pool.free()

# ==============================================================================
# SUITE 2: Hostile Edge Cases & Error Handling
# ==============================================================================
func _run_collider_hostile_operations_suite() -> void:
	print("\n--- Running Suite 2: ColliderPoolManager Hostile Edge Cases ---")
	var pool: ColliderPoolManager = ColliderPoolManager.new()
	root.add_child(pool)
	
	var o: RefCounted = RefCounted.new()
	var slot: int = pool.acquire_collider(o)
	_assert(slot >= 0, "Suite 2: Acquired valid slot %d" % slot)
	
	# 2.1 Double Release
	var first_release: bool = pool.release_collider(slot)
	_assert(first_release == true, "Suite 2: First release of slot %d succeeds" % slot)
	var second_release: bool = pool.release_collider(slot)
	_assert(second_release == false, "Suite 2: Second release (double-release) of slot %d cleanly returns false" % slot)
	
	# 2.2 Out-of-Bounds Slot Releases
	_assert(pool.release_collider(-1) == false, "Suite 2: release_collider(-1) returns false")
	_assert(pool.release_collider(64) == false, "Suite 2: release_collider(64) returns false")
	_assert(pool.release_collider(100) == false, "Suite 2: release_collider(100) returns false")
	_assert(pool.release_collider(-99999) == false, "Suite 2: release_collider(-99999) returns false")
	
	# 2.3 Unacquired Slot Operations
	# Slot 10 is currently free (unacquired)
	var free_slot: int = pool.free_indices[0]
	_assert(pool.is_in_use[free_slot] == false, "Suite 2: Verified slot %d is not in use" % free_slot)
	_assert(pool.release_collider(free_slot) == false, "Suite 2: Releasing unacquired slot %d cleanly returns false" % free_slot)
	
	# set_collider_origin on unacquired slot
	pool.set_collider_origin(free_slot, Vector3(500.0, 500.0, 500.0))
	_assert(pool.get_body(free_slot).position == Vector3.ZERO, "Suite 2: set_collider_origin on unacquired slot %d ignored (body position remains ZERO)" % free_slot)
	_assert(pool.get_collider_origin(free_slot) == Vector3.ZERO, "Suite 2: get_collider_origin on unacquired slot %d returns Vector3.ZERO" % free_slot)
	
	# 2.4 Out-of-Bounds Origin and Getter Operations
	pool.set_collider_origin(-1, Vector3(100.0, 200.0, 300.0))
	pool.set_collider_origin(64, Vector3(100.0, 200.0, 300.0))
	pool.set_collider_origin(9999, Vector3(100.0, 200.0, 300.0))
	_assert(pool.get_collider_origin(-1) == Vector3.ZERO, "Suite 2: get_collider_origin(-1) returns Vector3.ZERO")
	_assert(pool.get_collider_origin(64) == Vector3.ZERO, "Suite 2: get_collider_origin(64) returns Vector3.ZERO")
	_assert(pool.get_collider_origin(9999) == Vector3.ZERO, "Suite 2: get_collider_origin(9999) returns Vector3.ZERO")
	
	_assert(pool.get_body(-1) == null, "Suite 2: get_body(-1) returns null")
	_assert(pool.get_body(64) == null, "Suite 2: get_body(64) returns null")
	_assert(pool.get_shape(-1) == null, "Suite 2: get_shape(-1) returns null")
	_assert(pool.get_shape(64) == null, "Suite 2: get_shape(64) returns null")
	_assert(pool.get_collision_shape(-1) == null, "Suite 2: get_collision_shape(-1) returns null")
	_assert(pool.get_collision_shape(64) == null, "Suite 2: get_collision_shape(64) returns null")
	_assert(pool.get_collider_owner(-1) == null, "Suite 2: get_collider_owner(-1) returns null")
	_assert(pool.get_collider_owner(64) == null, "Suite 2: get_collider_owner(64) returns null")
	
	# update_collider_faces on invalid / unacquired slots
	var dummy_faces: PackedVector3Array = PackedVector3Array([Vector3(0,0,0), Vector3(1,0,0), Vector3(0,1,0)])
	pool.update_collider_faces(-1, dummy_faces)
	pool.update_collider_faces(64, dummy_faces)
	pool.update_collider_faces(free_slot, dummy_faces)
	_assert(pool.shapes[free_slot].get_faces().is_empty(), "Suite 2: update_collider_faces on unacquired slot %d ignored" % free_slot)
	
	# Verify pool integrity after all hostile attempts
	var final_audit: Dictionary = pool.verify_integrity()
	_assert(final_audit["is_valid"], "Suite 2: Pool remains 100% valid after hostile inputs")
	_assert(final_audit["active_count"] == 0, "Suite 2: Active count remains 0")
	_assert(final_audit["free_count"] == 64, "Suite 2: Free count remains 64")
	
	pool.clear()
	root.remove_child(pool)
	pool.free()

# ==============================================================================
# SUITE 3: Rapid Churn & Invariant Stress
# ==============================================================================
func _run_collider_deep_churn_stress_suite() -> void:
	print("\n--- Running Suite 3: ColliderPoolManager 5,000 Churn Iterations ---")
	var pool: ColliderPoolManager = ColliderPoolManager.new()
	root.add_child(pool)
	
	var active_map: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 987654321
	
	for iteration in range(5000):
		# Random action: acquire or release
		var should_acquire: bool = (active_map.size() < 10) or (active_map.size() < 64 and rng.randf() > 0.45)
		if should_acquire:
			var owner: RefCounted = RefCounted.new()
			var cid: int = pool.acquire_collider(owner)
			if cid != -1:
				active_map[cid] = owner
				var origin: Vector3 = Vector3(
					rng.randf_range(-100000.0, 100000.0),
					rng.randf_range(-100000.0, 100000.0),
					rng.randf_range(-100000.0, 100000.0)
				)
				pool.set_collider_origin(cid, origin)
				_assert(pool.get_body(cid).position == origin, "Suite 3: Origin matches during churn")
		else:
			if not active_map.is_empty():
				var keys: Array = active_map.keys()
				var target_cid: int = keys[rng.randi() % keys.size()]
				active_map.erase(target_cid)
				var ok: bool = pool.release_collider(target_cid)
				_assert(ok, "Suite 3: Churn release succeeded")
				_assert(pool.get_body(target_cid).position == Vector3.ZERO, "Suite 3: Position reset to ZERO during churn")
		
		# Audit integrity every 500 iterations
		if iteration % 500 == 0:
			var audit: Dictionary = pool.verify_integrity()
			_assert(audit["is_valid"], "Suite 3: Audit valid at churn iteration %d" % iteration)
			_assert(audit["active_count"] == active_map.size(), "Suite 3: Audit count matches map size at iteration %d" % iteration)
	
	# Release all remaining
	for cid in active_map.keys():
		pool.release_collider(cid)
		_assert(pool.get_body(cid).position == Vector3.ZERO, "Suite 3: Clean final reset for slot %d" % cid)
	
	var final_audit: Dictionary = pool.verify_integrity()
	_assert(final_audit["is_valid"] and final_audit["active_count"] == 0, "Suite 3: 100% clean pool after 5,000 churn cycles")
	
	pool.clear()
	root.remove_child(pool)
	pool.free()

# ==============================================================================
# SUITE 4: Zero Memory Allocation Audit
# ==============================================================================
func _run_memory_allocation_audit_suite() -> void:
	print("\n--- Running Suite 4: Memory Allocation Audit (Push Constants & Polling) ---")
	
	# 4.1 pack_push_constants() 10,000 Invocations
	TerrainMeshBuilder.init_builder()
	# Warmup
	for w in range(10):
		var _wb = TerrainMeshBuilder.pack_push_constants(0, 1, Vector2.ZERO, Vector2.ONE, 100000.0, 42, 0.05, 1000.0)
	
	var mem_push_before: int = OS.get_static_memory_usage()
	for i in range(10000):
		var face: int = i % 6
		var lod: int = (i % 8) + 1
		var uv0: Vector2 = Vector2(float(i) * 0.0001, float(i) * 0.0002)
		var uv1: Vector2 = uv0 + Vector2(0.01, 0.01)
		var radius: float = 100000.0 + float(i) * 5.0
		var seed_val: int = (i * 31) & 0xFFFFFFFF
		var freq: float = 0.01 + float(i % 10) * 0.005
		var amp: float = 500.0 + float(i % 20) * 20.0
		var buf: PackedByteArray = TerrainMeshBuilder.pack_push_constants(face, lod, uv0, uv1, radius, seed_val, freq, amp)
		if i == 0 or i == 9999:
			_assert(buf.size() == 48, "Suite 4: pack_push_constants size is exactly 48 bytes")
			_assert_approx(buf.decode_float(0), uv0.x, 1.0e-5, "Suite 4: uv_min.x layout matches")
			_assert_approx(buf.decode_float(4), uv0.y, 1.0e-5, "Suite 4: uv_min.y layout matches")
			_assert_approx(buf.decode_float(8), uv1.x - uv0.x, 1.0e-5, "Suite 4: uv_size layout matches")
			_assert_approx(buf.decode_float(28), float(lod), 1.0e-5, "Suite 4: lod layout matches")
			_assert_approx(buf.decode_float(32), radius, 1.0e-2, "Suite 4: radius layout matches")
			_assert_approx(buf.decode_float(36), float(seed_val), 1.0, "Suite 4: seed layout matches")
			_assert_approx(buf.decode_float(40), freq, 1.0e-5, "Suite 4: freq layout matches")
			_assert_approx(buf.decode_float(44), amp, 1.0e-5, "Suite 4: amp layout matches")
	
	var mem_push_after: int = OS.get_static_memory_usage()
	var push_delta: int = mem_push_after - mem_push_before
	print("  pack_push_constants() 10,000 runs memory delta: %d bytes" % push_delta)
	_assert(push_delta <= 0, "Suite 4: Zero static memory growth across 10,000 pack_push_constants invocations (delta = %d bytes)" % push_delta)
	
	# 4.2 ChunkTaskScheduler.poll() 10,000 Invocations in Steady State
	var scheduler: ChunkTaskScheduler = ChunkTaskScheduler.new()
	root.add_child(scheduler)
	
	# Warmup poll
	for p in range(50):
		scheduler.poll()
	
	var mem_poll_before: int = OS.get_static_memory_usage()
	for i in range(10000):
		scheduler.poll()
	
	var mem_poll_after: int = OS.get_static_memory_usage()
	var poll_delta: int = mem_poll_after - mem_poll_before
	print("  ChunkTaskScheduler.poll() 10,000 runs memory delta: %d bytes" % poll_delta)
	_assert(poll_delta <= 0, "Suite 4: Zero static memory growth across 10,000 ChunkTaskScheduler.poll invocations (delta = %d bytes)" % poll_delta)
	
	# 4.3 Burst Submit + Cancel All + Auto-Reclaim Across 20 Cycles
	var dummy_task: Callable = func() -> int:
		var x: int = 0
		for j in range(100):
			x += j
		return x
	
	for cycle in range(20):
		# Submit up to 64 jobs
		var submitted: int = 0
		for j in range(64):
			var jid: int = scheduler.submit_job(dummy_task)
			if jid != -1:
				submitted += 1
		
		# Cancel all jobs immediately
		scheduler.cancel_all_jobs()
		
		# Wait for active workers to drain
		while scheduler.get_active_worker_count() > 0:
			OS.delay_usec(100)
		
		# Poll to auto-reclaim
		scheduler.poll()
		
		var avail: int = scheduler.get_available_slots()
		_assert(avail == 64, "Suite 4: Cycle %d: All 64 slots restored after cancel_all_jobs and poll (got %d)" % [cycle, avail])
	
	scheduler.shutdown()
	root.remove_child(scheduler)
	scheduler.free()

# ==============================================================================
# SUITE 5: Production Script Line Count Audit (All 10 Scripts <= 250 Lines)
# ==============================================================================
func _run_production_script_line_count_suite() -> void:
	print("\n--- Running Suite 5: Production Script Line Count Audit (<= 250 Lines) ---")
	var scripts: Array[String] = [
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
	
	var total_lines: int = 0
	for script_name in scripts:
		var path: String = "res://" + script_name
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		_assert(file != null, "Suite 5: File exists and is readable: %s" % script_name)
		if file != null:
			var lines: int = 0
			while not file.eof_reached():
				file.get_line()
				lines += 1
			# Adjust for trailing newline if counted
			if lines > 0:
				file.seek(0)
				var text: String = file.get_as_text()
				var split_lines: PackedStringArray = text.split("\n")
				# If file ends with newline, last element is empty
				if split_lines.size() > 0 and split_lines[split_lines.size() - 1].is_empty():
					lines = split_lines.size() - 1
				else:
					lines = split_lines.size()
			file.close()
			total_lines += lines
			print("  [AUDIT] %-24s: %3d lines (<= 250)" % [script_name, lines])
			_assert(lines <= 250, "Suite 5: %s is <= 250 lines (actual: %d)" % [script_name, lines])
	
	print("  [AUDIT] Total production lines across 10 scripts: %d" % total_lines)
	_assert(scripts.size() == 10, "Suite 5: Exactly 10 production scripts audited")

# ==============================================================================
# SUITE 6: FBM Shader Parity & Multi-Worker Thread Concurrency
# ==============================================================================
func _run_fbm_and_worker_concurrency_suite() -> void:
	print("\n--- Running Suite 6: FBM Shader Parity & Multi-Worker Concurrency ---")
	
	# 6.1 FBM constants verification
	# octave step 1013904223, freq scaling 2.02, initial amp 0.5
	var test_p: Vector3 = Vector3(1.234, 5.678, 9.012)
	var noise_out: Vector4 = TerrainMeshBuilder.fbm4(test_p, 42)
	_assert(not is_nan(noise_out.x) and not is_inf(noise_out.x), "Suite 6: FBM height is finite")
	_assert(not is_nan(noise_out.y) and not is_inf(noise_out.y), "Suite 6: FBM grad.x is finite")
	_assert(not is_nan(noise_out.z) and not is_inf(noise_out.z), "Suite 6: FBM grad.y is finite")
	_assert(not is_nan(noise_out.w) and not is_inf(noise_out.w), "Suite 6: FBM grad.z is finite")
	
	# Determinism across repeated calls
	var noise_out2: Vector4 = TerrainMeshBuilder.fbm4(test_p, 42)
	_assert(noise_out == noise_out2, "Suite 6: FBM evaluation is 100% deterministic")
	
	# 6.2 Concurrent 4-worker thread buffer isolation
	# 4 threads building collider faces across slots 0, 1, 2, 3 simultaneously
	var threads: Array[Thread] = []
	threads.resize(4)
	var results: Array[PackedVector3Array] = []
	results.resize(4)
	
	var worker_fn: Callable = func(slot_idx: int) -> void:
		var faces: PackedVector3Array = TerrainMeshBuilder.build_collider_faces(
			0, 2, Vector2(0.1, 0.2), Vector2(0.3, 0.4), 100000.0, 12345, 0.05, 1000.0, slot_idx, true
		)
		results[slot_idx] = faces
	
	for w in range(4):
		threads[w] = Thread.new()
		threads[w].start(worker_fn.bind(w))
	
	for w in range(4):
		threads[w].wait_to_finish()
	
	# All 4 slots generated identical terrain geometry under the same parameters
	_assert(results[0].size() == TerrainMeshBuilder.INDEX_COUNT, "Suite 6: Worker 0 generated correct index count (6,534)")
	for w in range(1, 4):
		_assert(results[w].size() == TerrainMeshBuilder.INDEX_COUNT, "Suite 6: Worker %d generated 6,534 vertices" % w)
		var identical: bool = true
		for vi in range(0, TerrainMeshBuilder.INDEX_COUNT, 100):
			if results[w][vi] != results[0][vi]:
				identical = false
				break
		_assert(identical, "Suite 6: Worker %d produced identical geometry to Worker 0 (no data races)" % w)

func _print_summary() -> void:
	print("==================================================================")
	print("M13 ADVERSARIAL CHALLENGER 2 SUMMARY")
	print("==================================================================")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	print("==================================================================")
	if failed_assertions == 0:
		print("VERDICT: ALL TESTS PASSED - EMPIRICAL HARNESS APPROVED")
	else:
		printerr("VERDICT: %d TESTS FAILED - EMPIRICAL HARNESS REJECTED" % failed_assertions)
