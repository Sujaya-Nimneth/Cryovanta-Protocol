extends SceneTree

# ==============================================================================
# CRYOVANTA PROTOCOL: EMPIRICAL CHALLENGER HARDENING & STRESS TEST HARNESS
# ==============================================================================
# Adversarially tests:
# 1. PlanetMath zero-allocation invariant (face_uv_to_sphere_dir, get_chunk_center, get_chunk_radius)
# 2. QuadtreeNode.split() 0 dictionary and 0 temporary rects array allocations
# 3. 10,000 iterations of split/merge stress with zero memory leaks
# 4. Deep LOD stress & pool boundary exhaustion resilience
# 5. Full PlanetManager 10,000 dynamic camera LOD updates across all 6 faces
# 6. 10,000 rebase cycles on 64-bit sector arithmetic and hierarchy guards
# ==============================================================================

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("==================================================================")
	print("CHALLENGER HARDENING: ADVERSARIAL EMPIRICAL STRESS TEST SUITE")
	print("==================================================================")
	
	test_planet_math_zero_allocation()
	test_quadtree_split_zero_allocation_10k()
	test_deep_lod_pool_boundary_stress()
	test_planet_manager_10k_camera_stress()
	test_sector_math_10k_rebases()
	test_hierarchy_and_duplicate_rebase_guards()
	
	print("==================================================================")
	print("CHALLENGER HARDENING VERIFICATION SUMMARY")
	print("  Total Assertions:  %d" % total_assertions)
	print("  Passed Assertions: %d" % passed_assertions)
	print("  Failed Assertions: %d" % failed_assertions)
	print("==================================================================")
	
	if failed_assertions == 0:
		print("VERDICT: APPROVE - All 10,000-iteration stress & zero-allocation invariants confirmed!")
		quit(0)
	else:
		printerr("VERDICT: REQUEST_CHANGES - %d assertions failed!" % failed_assertions)
		quit(1)

func assert_true(condition: bool, msg: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("  [FAIL] %s" % msg)

func assert_eq(a: Variant, b: Variant, msg: String) -> void:
	total_assertions += 1
	if a == b:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("  [FAIL] %s: Expected %s, got %s" % [msg, str(b), str(a)])

func assert_near(a: float, b: float, tolerance: float, msg: String) -> void:
	total_assertions += 1
	if absf(a - b) <= tolerance:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("  [FAIL] %s: Difference %e exceeds tolerance %e" % [msg, absf(a - b), tolerance])

# ------------------------------------------------------------------------------
# TEST 1: PlanetMath Zero-Allocation Invariants
# ------------------------------------------------------------------------------
func test_planet_math_zero_allocation() -> void:
	print("\n--- TEST 1: PlanetMath Zero-Allocation & Correctness (50,000 Iterations) ---")
	
	# Verify face normals, tangents, bitangents are precomputed arrays
	assert_eq(PlanetMath.FACE_NORMALS.size(), 6, "FACE_NORMALS has 6 elements")
	assert_eq(PlanetMath.FACE_TANGENTS.size(), 6, "FACE_TANGENTS has 6 elements")
	assert_eq(PlanetMath.FACE_BITANGENTS.size(), 6, "FACE_BITANGENTS has 6 elements")
	
	# Verify orthogonality of precomputed basis vectors
	for f in range(6):
		var n: Vector3 = PlanetMath.FACE_NORMALS[f]
		var t: Vector3 = PlanetMath.FACE_TANGENTS[f]
		var b: Vector3 = PlanetMath.FACE_BITANGENTS[f]
		assert_near(n.dot(t), 0.0, 1e-6, "Face %d: Normal orthogonal to Tangent" % f)
		assert_near(n.dot(b), 0.0, 1e-6, "Face %d: Normal orthogonal to Bitangent" % f)
		assert_near(t.dot(b), 0.0, 1e-6, "Face %d: Tangent orthogonal to Bitangent" % f)
		assert_near(n.cross(t).normalized().dot(b.normalized()), 1.0, 1e-4, "Face %d: Right-handed basis" % f)
	
	# Warm-up loop
	for i in range(1000):
		var _d: Vector3 = PlanetMath.face_uv_to_sphere_dir(i % 6, Vector2(0.1, -0.2))
		var _c: Vector3 = PlanetMath.get_chunk_center(i % 6, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100000.0)
		var _r: float = PlanetMath.get_chunk_radius(i % 6, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), _c, 100000.0)
	
	# Test face_uv_to_sphere_dir zero heap allocation over 50,000 iterations
	var dir_len_acc: float = 0.0
	var mem_before_dir: int = OS.get_static_memory_usage()
	for i in range(50000):
		var uv: Vector2 = Vector2(-1.0 + (i % 200) * 0.01, 1.0 - (i % 150) * 0.013)
		var dir: Vector3 = PlanetMath.face_uv_to_sphere_dir(i % 6, uv)
		dir_len_acc += dir.length()
	var mem_after_dir: int = OS.get_static_memory_usage()
	var dir_delta: int = mem_after_dir - mem_before_dir
	assert_eq(dir_delta, 0, "PlanetMath.face_uv_to_sphere_dir() 50k calls has 0 heap allocation (delta: %d bytes)" % dir_delta)
	assert_near(dir_len_acc / 50000.0, 1.0, 1e-5, "Average direction length is strictly 1.0")
	
	# Test get_chunk_center and get_chunk_radius zero heap allocation over 50,000 iterations
	var radius_test: float = 100000.0
	var min_uv: Vector2 = Vector2(-0.8, -0.8)
	var max_uv: Vector2 = Vector2(0.8, 0.8)
	var center_len_acc: float = 0.0
	var rad_acc: float = 0.0
	
	var mem_before_bounds: int = OS.get_static_memory_usage()
	for i in range(50000):
		var center: Vector3 = PlanetMath.get_chunk_center(i % 6, min_uv, max_uv, radius_test)
		var rad: float = PlanetMath.get_chunk_radius(i % 6, min_uv, max_uv, center, radius_test)
		center_len_acc += center.length()
		rad_acc += rad
	var mem_after_bounds: int = OS.get_static_memory_usage()
	var bounds_delta: int = mem_after_bounds - mem_before_bounds
	assert_eq(bounds_delta, 0, "PlanetMath.get_chunk_center/radius 50k calls has 0 heap allocation (delta: %d bytes)" % bounds_delta)
	assert_near(center_len_acc / 50000.0, radius_test, 1e-3, "Average chunk center length equals planet radius")
	assert_true(rad_acc > 0.0, "Total chunk radius sum is positive")

# ------------------------------------------------------------------------------
# TEST 2: QuadtreeNode.split() Zero-Allocation 10,000 Iterations Stress
# ------------------------------------------------------------------------------
func test_quadtree_split_zero_allocation_10k() -> void:
	print("\n--- TEST 2: QuadtreeNode.split() 10,000 Split/Merge Stress Test ---")
	
	QuadtreeNode.init_pool()
	var pool: ChunkPoolManager = ChunkPoolManager.new()
	var root: QuadtreeNode = QuadtreeNode.acquire_node()
	root.init_node(0, 0, Vector2(-1.0, -1.0), Vector2(1.0, 1.0), null, 100000.0)
	root.mesh_id = pool.acquire_mesh(root)
	
	assert_eq(pool.get_active_count(), 1, "Initial active mesh count is 1")
	assert_eq(QuadtreeNode.get_active_node_count(), 1, "Initial active node count is 1")
	
	# Warm-up 100 cycles to stabilize any internal arrays
	for _w in range(100):
		root.split(pool, 100000.0)
		root.merge(pool)
	
	assert_eq(pool.get_active_count(), 1, "After warmup: pool active count is 1")
	assert_eq(QuadtreeNode.get_active_node_count(), 1, "After warmup: active node count is 1")
	
	# 10,000 Iterations Split & Merge Stress Test
	var time_start: int = Time.get_ticks_usec()
	var mem_start: int = OS.get_static_memory_usage()
	
	for i in range(10000):
		root.split(pool, 100000.0)
		root.merge(pool)
	
	var mem_end: int = OS.get_static_memory_usage()
	var time_end: int = Time.get_ticks_usec()
	var elapsed_ms: float = (time_end - time_start) / 1000.0
	var mem_delta: int = mem_end - mem_start
	
	print("  Executed 10,000 split/merge cycles in %.2f ms (%.3f µs per cycle)" % [elapsed_ms, (time_end - time_start) / 10000.0])
	print("  Memory before: %d bytes | Memory after: %d bytes | Delta: %d bytes" % [mem_start, mem_end, mem_delta])
	
	assert_eq(mem_delta, 0, "10,000 split/merge cycles resulted in EXACTLY 0 net heap allocations")
	assert_eq(pool.get_active_count(), 1, "Final active meshes in pool is 1")
	assert_eq(QuadtreeNode.get_active_node_count(), 1, "Final active node count is 1")
	
	# Verify pool integrity
	var pool_audit: Dictionary = pool.verify_integrity()
	assert_true(pool_audit.is_valid, "ChunkPoolManager integrity 100% valid after 10k cycles")
	assert_eq(pool_audit.errors.size(), 0, "Zero errors in pool audit")
	
	# Teardown root
	root.merge(pool)
	pool.release_mesh(root.mesh_id)
	QuadtreeNode.release_node(root)
	pool.clear()
	QuadtreeNode.clear_pool()

# ------------------------------------------------------------------------------
# TEST 3: Deep LOD Subdivision & Pool Boundary Exhaustion Resilience
# ------------------------------------------------------------------------------
func test_deep_lod_pool_boundary_stress() -> void:
	print("\n--- TEST 3: Deep LOD Subdivision & Pool Boundary Exhaustion Resilience ---")
	
	QuadtreeNode.init_pool()
	var pool: ChunkPoolManager = ChunkPoolManager.new()
	var root: QuadtreeNode = QuadtreeNode.acquire_node()
	root.init_node(0, 0, Vector2(-1.0, -1.0), Vector2(1.0, 1.0), null, 100000.0)
	root.mesh_id = pool.acquire_mesh(root)
	
	# Split to LOD 1 (4 children, 4 meshes)
	assert_true(root.split(pool, 100000.0), "Split root to LOD 1")
	assert_eq(pool.get_active_count(), 4, "Active meshes == 4")
	
	# Split all 4 children to LOD 2 (16 leaves, 16 meshes)
	for c in root.children:
		assert_true(c.split(pool, 100000.0), "Split child to LOD 2")
	assert_eq(pool.get_active_count(), 16, "Active meshes == 16")
	
	# Split all 16 grandchildren to LOD 3 (64 leaves, 64 meshes)
	for c in root.children:
		for gc in c.children:
			assert_true(gc.split(pool, 100000.0), "Split grandchild to LOD 3")
	assert_eq(pool.get_active_count(), 64, "Active meshes == 64")
	
	# Adversarial: Attempt splitting an already split internal node -> must fail gracefully
	assert_true(not root.split(pool, 100000.0), "Attempt to split non-leaf root fails cleanly")
	assert_true(not root.children[0].split(pool, 100000.0), "Attempt to split non-leaf child fails cleanly")
	
	# Adversarial: Attempt merge on a leaf node -> must fail cleanly
	var leaf_node: QuadtreeNode = root.children[0].children[0].children[0]
	assert_true(leaf_node.is_leaf, "Target is confirmed leaf")
	assert_true(not leaf_node.merge(pool), "Attempt to merge leaf node returns false cleanly")
	
	# Force merge back to LOD 0
	root.force_merge(pool)
	assert_true(root.is_leaf, "Root is leaf after force_merge")
	assert_eq(pool.get_active_count(), 1, "Pool active meshes restored to 1")
	assert_eq(QuadtreeNode.get_active_node_count(), 1, "Active nodes restored to 1")
	assert_true(pool.verify_integrity().is_valid, "Pool integrity intact after deep collapse")
	
	# Teardown
	pool.release_mesh(root.mesh_id)
	QuadtreeNode.release_node(root)
	pool.clear()
	QuadtreeNode.clear_pool()

# ------------------------------------------------------------------------------
# TEST 4: Full PlanetManager 10,000-Step Dynamic Camera LOD Stress Test
# ------------------------------------------------------------------------------
func test_planet_manager_10k_camera_stress() -> void:
	print("\n--- TEST 4: Full PlanetManager 10,000-Step Dynamic Camera LOD Stress Test ---")
	
	var pm: PlanetManager = PlanetManager.new()
	pm.planet_radius = 100000.0
	pm.max_lod = 4
	pm.split_ratio = 2.0
	pm.hysteresis = 1.3
	
	# Initial verification
	var audit_init: Dictionary = pm.audit_system()
	assert_true(audit_init.is_valid, "Initial PlanetManager audit is 100% valid")
	assert_eq(audit_init.active_meshes, 6, "Initial active meshes is 6")
	assert_eq(audit_init.leaf_nodes, 6, "Initial leaf nodes is 6")
	
	# Warm up 500 steps to reach stable pool allocation
	for w in range(500):
		var phase: float = w * 0.05
		var alt: float = 120000.0 + sin(phase) * 30000.0
		var test_cam: Vector3 = Vector3(cos(phase) * alt, sin(phase) * alt, 0)
		pm.update_camera(test_cam)
	
	# Retreat to LOD 0
	pm.update_camera(Vector3(10000000.0, 0.0, 0.0))
	var audit_post_warmup: Dictionary = pm.audit_system()
	assert_true(audit_post_warmup.is_valid, "Audit post warmup is valid")
	
	# Measure memory delta purely around the 10,000 camera movements
	var mem_start: int = OS.get_static_memory_usage()
	var time_start: int = Time.get_ticks_usec()
	
	# 10,000 Camera movements stress test:
	# Simulates dynamic trajectory orbiting around all 6 faces, crossing corners,
	# plunging from deep space (1,000,000m) to near-surface (101,000m) and back.
	for step in range(10000):
		var phase: float = step * 0.02
		var altitude: float = 100500.0 + 400000.0 * (0.5 + 0.5 * sin(step * 0.003))
		var cam_pos: Vector3 = Vector3(
			cos(phase) * cos(phase * 0.7) * altitude,
			sin(phase * 0.5) * altitude,
			sin(phase) * cos(phase * 0.3) * altitude
		)
		pm.update_camera(cam_pos)
	
	# Retreat camera to deep space (forcing complete collapse of all 6 faces back to LOD 0)
	pm.update_camera(Vector3(10000000.0, 0.0, 0.0))
	
	var time_end: int = Time.get_ticks_usec()
	var mem_end: int = OS.get_static_memory_usage()
	var elapsed_ms: float = (time_end - time_start) / 1000.0
	var mem_delta: int = mem_end - mem_start
	
	print("  Executed 10,000 PlanetManager.update_camera() calls in %.2f ms (%.3f µs per call)" % [
		elapsed_ms, (time_end - time_start) / 10000.0
	])
	print("  Memory before: %d bytes | Memory after: %d bytes | Delta: %d bytes" % [mem_start, mem_end, mem_delta])
	
	# Structural audit
	var audit_final: Dictionary = pm.audit_system()
	assert_true(audit_final.is_valid, "Final audit after retreat is 100% valid")
	assert_eq(audit_final.orphan_count, 0, "Final orphan count is 0")
	assert_eq(audit_final.leaf_nodes, 6, "Final active leaf chunks returned to exactly 6 at LOD 0")
	assert_eq(audit_final.active_meshes, 6, "Final active meshes returned to exactly 6 at LOD 0")
	assert_eq(audit_final.free_meshes, 250, "Final free meshes returned to exactly 250")
	
	# Assert zero memory growth
	assert_true(mem_delta <= 0, "No memory growth across 10,000 LOD updates (delta: %d bytes)" % mem_delta)
	
	pm.destroy()
	pm.free()

# ------------------------------------------------------------------------------
# TEST 5: 64-Bit Equivalent Sector Coordinate Arithmetic (10,000 Rebases)
# ------------------------------------------------------------------------------
func test_sector_math_10k_rebases() -> void:
	print("\n--- TEST 5: 64-Bit Sector Coordinate Arithmetic Across 10,000 Rebases ---")
	
	var fo: FloatingOrigin = FloatingOrigin.new()
	var pm: PlanetManager = PlanetManager.new()
	fo.planet_manager = pm
	
	var expected_total_offset: Vector3 = Vector3.ZERO
	
	for i in range(10000):
		# Rebase by varied offsets across all axes
		var shift: Vector3 = Vector3(
			2000.0 + (i % 7) * 500.0,
			-2500.0 - (i % 5) * 400.0,
			1800.0 + (i % 11) * 300.0
		)
		fo.rebase(shift)
		expected_total_offset += shift
		
		if i % 2500 == 0:
			# Verify sector + local matches accumulated offset
			var fo_reconstructed: Vector3 = Vector3(fo.origin_sector) * FloatingOrigin.SECTOR_SIZE + fo.origin_local
			assert_near(fo_reconstructed.x, fo.accumulated_offset.x, 1e-2, "FO Sector X match step %d" % i)
			assert_near(fo_reconstructed.y, fo.accumulated_offset.y, 1e-2, "FO Sector Y match step %d" % i)
			assert_near(fo_reconstructed.z, fo.accumulated_offset.z, 1e-2, "FO Sector Z match step %d" % i)
			
			var pm_reconstructed: Vector3 = Vector3(pm.planet_center_sector) * PlanetManager.SECTOR_SIZE + pm.planet_center_local
			assert_near(pm_reconstructed.x, pm.planet_center_offset.x, 1e-2, "PM Sector X match step %d" % i)
			assert_near(pm_reconstructed.y, pm.planet_center_offset.y, 1e-2, "PM Sector Y match step %d" % i)
			assert_near(pm_reconstructed.z, pm.planet_center_offset.z, 1e-2, "PM Sector Z match step %d" % i)
	
	# Verify final astronomical coordinates
	print("  Completed 10,000 rebases. Total accumulated offset: %s" % str(fo.accumulated_offset))
	print("  Final origin_sector: %s | origin_local: %s" % [str(fo.origin_sector), str(fo.origin_local)])
	print("  Final planet_center_sector: %s | planet_center_local: %s" % [str(pm.planet_center_sector), str(pm.planet_center_local)])
	
	var final_reconstructed: Vector3 = Vector3(fo.origin_sector) * FloatingOrigin.SECTOR_SIZE + fo.origin_local
	assert_near(final_reconstructed.x, expected_total_offset.x, 1e-1, "Final reconstructed total X match")
	assert_near(final_reconstructed.y, expected_total_offset.y, 1e-1, "Final reconstructed total Y match")
	assert_near(final_reconstructed.z, expected_total_offset.z, 1e-1, "Final reconstructed total Z match")
	
	# Invariant: local offset magnitude within [0, SECTOR_SIZE) on all axes
	assert_true(fo.origin_local.x >= 0.0 and fo.origin_local.x < FloatingOrigin.SECTOR_SIZE, "fo.origin_local.x in [0, 2000)")
	assert_true(fo.origin_local.y >= 0.0 and fo.origin_local.y < FloatingOrigin.SECTOR_SIZE, "fo.origin_local.y in [0, 2000)")
	assert_true(fo.origin_local.z >= 0.0 and fo.origin_local.z < FloatingOrigin.SECTOR_SIZE, "fo.origin_local.z in [0, 2000)")
	
	pm.destroy()
	pm.free()
	fo.free()

# ------------------------------------------------------------------------------
# TEST 6: Hierarchy Ancestor Guards & Spaceship Double-Rebase Deduplication
# ------------------------------------------------------------------------------
func test_hierarchy_and_duplicate_rebase_guards() -> void:
	print("\n--- TEST 6: Hierarchy Ancestor Guards & Spaceship Double-Rebase Deduplication ---")
	
	var fo: FloatingOrigin = FloatingOrigin.new()
	var ship: SpaceshipController = SpaceshipController.new()
	var camera: Camera3D = Camera3D.new()
	var greeble: Node3D = Node3D.new()
	
	# Hierarchy: ship -> camera -> greeble
	ship.add_child(camera)
	camera.add_child(greeble)
	
	fo.player_node = ship
	fo.register_entity(camera)
	fo.register_entity(greeble)
	
	ship.position = Vector3(3000.0, 0.0, 0.0)
	camera.position = Vector3(0.0, 2.0, 5.0)     # local to ship
	greeble.position = Vector3(0.1, 0.0, 0.0)    # local to camera
	
	var initial_ship_pos: Vector3 = ship.position
	var initial_cam_local: Vector3 = camera.position
	var initial_greeble_local: Vector3 = greeble.position
	
	# Perform rebase: offset = (3000, 0, 0)
	fo.rebase(Vector3(3000.0, 0.0, 0.0))
	
	# Ship shifted from 3000 to 0
	assert_near(ship.position.x, 0.0, 1e-4, "Ship shifted by 3000 to 0")
	# Children MUST NOT be shifted in local space (since they inherit parent shift)
	assert_eq(camera.position, initial_cam_local, "Camera local position unchanged (no double-shift)")
	assert_eq(greeble.position, initial_greeble_local, "Greeble local position unchanged (no double-shift)")
	
	# Test SpaceshipController double-rebase guard in same physics frame
	ship.linear_velocity = Vector3(100.0, 20.0, -50.0)
	ship.angular_velocity = Vector3(0.1, -0.2, 0.05)
	
	# Call rebase_origin once
	ship.rebase_origin(Vector3(500.0, 0.0, 0.0))
	var pos_after_first: Vector3 = ship.position
	assert_near(pos_after_first.x, -500.0, 1e-4, "Ship shifted by 500 to -500")
	
	# Call rebase_origin again in SAME frame with SAME offset
	ship.rebase_origin(Vector3(500.0, 0.0, 0.0))
	assert_eq(ship.position, pos_after_first, "Duplicate rebase_origin in same frame is ignored")
	
	# Assert velocities remain intact with 0 spike
	assert_eq(ship.linear_velocity, Vector3(100.0, 20.0, -50.0), "Linear velocity intact (< 1e-4)")
	assert_eq(ship.angular_velocity, Vector3(0.1, -0.2, 0.05), "Angular velocity intact (< 1e-4)")
	
	# Clean up hierarchy: freeing root node frees all its children automatically
	ship.free()
	fo.free()
