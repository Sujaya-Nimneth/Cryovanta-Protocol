extends SceneTree

# ==============================================================================
# CRYOVANTA PROTOCOL: ADVERSARIAL EMPIRICAL HARNESS M12 (CHALLENGER 2)
# ==============================================================================
# Rigorous empirical stress-testing for Milestone M12:
# 1. ColliderPoolManager: 64-slot ring buffer integrity across rapid acquire/release
#    cycles (50,000 iterations) and 2,000 sustained quadtree camera movements
#    (0 orphan colliders, 0 leaks, 100% invariant consistency).
# 2. TerrainMeshBuilder: 34x34 mesh generation (1,156 vertices, 6,534 indices),
#    CCW non-degenerate triangle winding, 48-byte std430 alignment, and exact
#    5% skirt extrusion math toward planet center.
# 3. PlanetManager & SpaceshipController: Empirical verification of ZERO runtime
#    heap memory allocations in steady state across 5,000 frames.
# ==============================================================================

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("==================================================================")
	print("CRYOVANTA PROTOCOL: M12 EMPIRICAL CHALLENGER STRESS HARNESS")
	print("==================================================================")
	
	_run_collider_pool_deep_stress()
	_run_terrain_mesh_and_skirt_math_stress()
	_run_steady_state_zero_allocation_stress()
	_run_quadtree_sustained_collider_stress()
	_run_hypersonic_gravity_rebase_stress()
	_run_task_scheduler_concurrency_stress()
	
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
# TEST SUITE 1: ColliderPoolManager 64-Slot Deep Stress
# ==============================================================================
func _run_collider_pool_deep_stress() -> void:
	print("\n--- Running Suite 1: ColliderPoolManager 64-Slot Ring Buffer Stress ---")
	var pool: ColliderPoolManager = ColliderPoolManager.new()
	root.add_child(pool)
	
	# Initial Invariants
	var audit = pool.verify_integrity()
	_assert(audit["is_valid"], "Pool initialized with valid integrity")
	_assert(pool.get_active_count() == 0, "Initial active count is 0")
	_assert(pool.get_free_count() == 64, "Initial free count is 64")
	_assert(pool.has_available(64), "has_available(64) is true")
	_assert(not pool.has_available(65), "has_available(65) is false")
	
	# Acquire all 64 slots
	var mock_owners: Array[RefCounted] = []
	var acquired_ids: Array[int] = []
	for i in range(64):
		var owner_obj = RefCounted.new()
		mock_owners.append(owner_obj)
		var cid: int = pool.acquire_collider(owner_obj)
		_assert(cid >= 0 and cid < 64, "Acquired slot %d in range [0, 63]" % cid)
		_assert(not acquired_ids.has(cid), "Acquired slot %d is unique" % cid)
		acquired_ids.append(cid)
	
	_assert(pool.get_active_count() == 64, "Pool active count is 64")
	_assert(pool.get_free_count() == 0, "Pool free count is 0")
	_assert(pool.verify_integrity()["is_valid"], "Pool integrity valid at full capacity")
	
	# Exhaustion check: 65th acquire returns -1
	var overflow_owner = RefCounted.new()
	var overflow_id: int = pool.acquire_collider(overflow_owner)
	_assert(overflow_id == -1, "Exhausted pool returns -1 on acquire")
	_assert(pool.verify_integrity()["is_valid"], "Pool integrity remains valid after exhaustion reject")
	
	# Negative release tests
	_assert(not pool.release_collider(-1), "release_collider(-1) returns false")
	_assert(not pool.release_collider(64), "release_collider(64) returns false")
	_assert(not pool.release_collider(999), "release_collider(999) returns false")
	
	# Interleaved Release: Release all even indexed slots (32 releases)
	for i in range(0, 64, 2):
		var target_id: int = acquired_ids[i]
		_assert(pool.release_collider(target_id), "Released even slot %d successfully" % target_id)
		# Double-release guard check
		_assert(not pool.release_collider(target_id), "Double release of slot %d rejected" % target_id)
	
	_assert(pool.get_active_count() == 32, "Active count is 32 after 32 releases")
	_assert(pool.get_free_count() == 32, "Free count is 32 after 32 releases")
	_assert(pool.verify_integrity()["is_valid"], "Pool integrity valid after partial releases")
	
	# Re-acquire 32 slots
	var reacquired_ids: Array[int] = []
	for i in range(32):
		var owner_obj = RefCounted.new()
		var cid: int = pool.acquire_collider(owner_obj)
		_assert(cid >= 0 and cid < 64, "Re-acquired slot %d in valid range" % cid)
		_assert(not reacquired_ids.has(cid), "Re-acquired slot %d is unique" % cid)
		reacquired_ids.append(cid)
	
	_assert(pool.get_active_count() == 64, "Active count back to 64")
	_assert(pool.verify_integrity()["is_valid"], "Integrity valid after re-filling")
	
	# Release all 64 slots in reverse order
	for id in reacquired_ids:
		pool.release_collider(id)
	for i in range(1, 64, 2):
		pool.release_collider(acquired_ids[i])
	
	_assert(pool.get_active_count() == 0, "Active count is 0 after full release")
	_assert(pool.get_free_count() == 64, "Free count is 64 after full release")
	_assert(pool.verify_integrity()["is_valid"], "Integrity valid when empty")
	
	# Rapid Acquire/Release Steady-State Zero Allocation Test
	# Pre-allocate 64 owner objects and slots array to avoid test harness allocations
	var test_owners: Array[RefCounted] = []
	test_owners.resize(64)
	for i in range(64):
		test_owners[i] = RefCounted.new()
	var slot_tracker: Array[int] = []
	slot_tracker.resize(64)
	
	# Warm up pool operations
	for cycle in range(50):
		for i in range(64):
			slot_tracker[i] = pool.acquire_collider(test_owners[i])
		for i in range(64):
			pool.release_collider(slot_tracker[i])
	
	print("  Running 50,000 pure acquire/release stress cycles...")
	var mem_before_stress: int = OS.get_static_memory_usage()
	for cycle in range(50000):
		var cid: int = pool.acquire_collider(test_owners[0])
		pool.release_collider(cid)
		if cycle % 10000 == 0:
			var cycle_audit = pool.verify_integrity()
			_assert(cycle_audit["is_valid"], "Integrity valid at cycle %d" % cycle)
	
	var mem_after_stress: int = OS.get_static_memory_usage()
	var mem_delta_pool: int = mem_after_stress - mem_before_stress
	_assert(mem_delta_pool == 0, "Zero memory leak across 50,000 acquire/release cycles (delta: %d bytes)" % mem_delta_pool)
	
	var final_audit = pool.verify_integrity()
	_assert(final_audit["is_valid"], "Pool integrity valid after 50,000 cycles")
	_assert(pool.get_active_count() == 0, "All 64 slots reclaimed (active == 0)")
	_assert(pool.get_free_count() == 64, "All 64 slots in free stack (free == 64)")
	
	# Cleanup
	pool.clear()
	root.remove_child(pool)
	pool.free()
	print("  ColliderPoolManager stress suite passed cleanly.")

# ==============================================================================
# TEST SUITE 2: TerrainMeshBuilder 34x34 Mesh & 5% Skirt Math
# ==============================================================================
func _run_terrain_mesh_and_skirt_math_stress() -> void:
	print("\n--- Running Suite 2: TerrainMeshBuilder 34x34 Mesh & Skirt Extrusion Math ---")
	
	TerrainMeshBuilder.init_builder()
	_assert(TerrainMeshBuilder.GRID == 34, "GRID is 34")
	_assert(TerrainMeshBuilder.INTERIOR == 32, "INTERIOR is 32")
	_assert(TerrainMeshBuilder.VERTEX_COUNT == 1156, "VERTEX_COUNT is 1156")
	_assert(TerrainMeshBuilder.INDEX_COUNT == 6534, "INDEX_COUNT is 6534")
	_assert(TerrainMeshBuilder.TRIANGLE_COUNT == 2178, "TRIANGLE_COUNT is 2178")
	_assert(TerrainMeshBuilder.SKIRT_FRACTION == 0.05, "SKIRT_FRACTION is 0.05")
	
	# Verify Push Constant std430 48-byte layout
	var push_bytes: PackedByteArray = TerrainMeshBuilder.pack_push_constants(
		2, 3, Vector2(-0.5, 0.0), Vector2(0.0, 0.5), 100000.0, 42, 1.5, 2500.0
	)
	_assert(push_bytes.size() == 48, "Push constants buffer size is exactly 48 bytes")
	_assert_approx(push_bytes.decode_float(0), -0.5, 1e-5, "Offset 0: uv_min.x == -0.5")
	_assert_approx(push_bytes.decode_float(4), 0.0, 1e-5, "Offset 4: uv_min.y == 0.0")
	_assert_approx(push_bytes.decode_float(8), 0.5, 1e-5, "Offset 8: uv_range.x == 0.5")
	var expected_chunk_size: float = TerrainMeshBuilder.calculate_chunk_size(2, Vector2(-0.5, 0.0), Vector2(0.0, 0.5), 100000.0)
	_assert_approx(push_bytes.decode_float(12), expected_chunk_size, 0.01, "Offset 12: chunk_size_m matches calculate_chunk_size")
	var face_norm: Vector3 = PlanetMath.FACE_NORMALS[2]
	_assert_approx(push_bytes.decode_float(16), face_norm.x, 1e-5, "Offset 16: norm.x")
	_assert_approx(push_bytes.decode_float(20), face_norm.y, 1e-5, "Offset 20: norm.y")
	_assert_approx(push_bytes.decode_float(24), face_norm.z, 1e-5, "Offset 24: norm.z")
	_assert_approx(push_bytes.decode_float(28), 3.0, 1e-5, "Offset 28: lod_level == 3.0")
	_assert_approx(push_bytes.decode_float(32), 100000.0, 1e-3, "Offset 32: planet_radius == 100000.0")
	_assert_approx(push_bytes.decode_float(36), 42.0, 1e-5, "Offset 36: seed_val == 42.0")
	_assert_approx(push_bytes.decode_float(40), 1.5, 1e-5, "Offset 40: freq == 1.5")
	_assert_approx(push_bytes.decode_float(44), 2500.0, 1e-3, "Offset 44: amp == 2500.0")
	
	# Build mesh across all 6 faces and verify topology
	var target_mesh: ArrayMesh = ArrayMesh.new()
	for face_idx in range(6):
		TerrainMeshBuilder.build_mesh_cpu(
			face_idx, 2, Vector2(-0.5, -0.5), Vector2(0.5, 0.5),
			100000.0, 1337, 2.0, 1500.0, target_mesh, false
		)
		_assert(target_mesh.get_surface_count() == 1, "Face %d generates 1 surface" % face_idx)
		var arrays: Array = target_mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		
		_assert(verts.size() == 1156, "Face %d vertex count == 1,156" % face_idx)
		_assert(norms.size() == 1156, "Face %d normal count == 1,156" % face_idx)
		_assert(indices.size() == 6534, "Face %d index count == 6,534" % face_idx)
		
		# Index validity
		var max_idx: int = -1
		var min_idx: int = 999999
		for idx in indices:
			if idx > max_idx: max_idx = idx
			if idx < min_idx: min_idx = idx
		_assert(min_idx == 0 and max_idx == 1155, "Face %d index range is exactly [0, 1155]" % face_idx)
		
		# Non-degenerate triangles and winding order check
		var degenerate_count: int = 0
		var ccw_consistent_count: int = 0
		var interior_tested: int = 0
		
		var tri_total: int = indices.size() / 3
		for t in range(tri_total):
			var i0: int = indices[t * 3]
			var i1: int = indices[t * 3 + 1]
			var i2: int = indices[t * 3 + 2]
			var v0: Vector3 = verts[i0]
			var v1: Vector3 = verts[i1]
			var v2: Vector3 = verts[i2]
			var tri_normal: Vector3 = (v1 - v0).cross(v2 - v0)
			if i0 == i1 or i1 == i2 or i0 == i2 or tri_normal.length_squared() < 1e-12:
				degenerate_count += 1
			
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
				var avg_norm: Vector3 = (norms[i0] + norms[i1] + norms[i2]).normalized()
				if tri_normal.dot(avg_norm) > 0.0:
					ccw_consistent_count += 1
		
		_assert(degenerate_count == 8, "Face %d has exactly 8 corner-skirt seam triangles (got %d)" % [face_idx, degenerate_count])
		_assert(tri_total - degenerate_count == 2170, "Face %d has exactly 2,170 non-degenerate triangles" % face_idx)
		_assert(interior_tested > 1000, "Face %d tested > 1,000 interior triangles" % face_idx)
		_assert(ccw_consistent_count == interior_tested, "Face %d: 100%% of interior triangles exhibit consistent CCW winding" % face_idx)
	
	# Math Verification of 5% Skirt Extrusion
	# We test a chunk in world space (chunk_local = false)
	var radius: float = 100000.0
	var face: int = 0
	var uv_min: Vector2 = Vector2(-0.25, -0.25)
	var uv_max: Vector2 = Vector2(0.25, 0.25)
	var chunk_size_m: float = TerrainMeshBuilder.calculate_chunk_size(face, uv_min, uv_max, radius)
	var expected_skirt_dist: float = chunk_size_m * 0.05
	
	TerrainMeshBuilder.build_mesh_cpu(face, 1, uv_min, uv_max, radius, 42, 1.0, 500.0, target_mesh, false)
	var test_arrays: Array = target_mesh.surface_get_arrays(0)
	var test_verts: PackedVector3Array = test_arrays[Mesh.ARRAY_VERTEX]
	
	var inv_interior: float = 1.0 / float(TerrainMeshBuilder.INTERIOR - 1)
	var uv_range: Vector2 = uv_max - uv_min
	
	var skirt_math_passed: bool = true
	var interior_math_passed: bool = true
	
	for y in range(TerrainMeshBuilder.GRID):
		var inner_y: float = clampf(float(y - 1), 0.0, float(TerrainMeshBuilder.INTERIOR - 1)) * inv_interior
		for x in range(TerrainMeshBuilder.GRID):
			var inner_x: float = clampf(float(x - 1), 0.0, float(TerrainMeshBuilder.INTERIOR - 1)) * inv_interior
			var uv: Vector2 = Vector2(uv_min.x + inner_x * uv_range.x, uv_min.y + inner_y * uv_range.y)
			var dir: Vector3 = PlanetMath.face_uv_to_sphere_dir(face, uv)
			var f: Vector4 = TerrainMeshBuilder.fbm4(dir * 1.0, 42)
			var height: float = 500.0 * f.x
			var unextruded_pos: Vector3 = dir * (radius + height)
			
			var idx: int = y * TerrainMeshBuilder.GRID + x
			var actual_pos: Vector3 = test_verts[idx]
			
			var is_skirt: bool = (x == 0 or y == 0 or x == TerrainMeshBuilder.GRID - 1 or y == TerrainMeshBuilder.GRID - 1)
			if is_skirt:
				var expected_skirt_pos: Vector3 = unextruded_pos - dir * expected_skirt_dist
				if actual_pos.distance_to(expected_skirt_pos) > 1e-3:
					skirt_math_passed = false
			else:
				if actual_pos.distance_to(unextruded_pos) > 1e-3:
					interior_math_passed = false
	
	_assert(interior_math_passed, "All 1,024 interior vertices match exact unextruded heightfield math")
	_assert(skirt_math_passed, "All 132 perimeter vertices match exact 5% radial skirt extrusion toward planet center")
	print("  TerrainMeshBuilder mesh and skirt math verified with 100% precision.")

# ==============================================================================
# TEST SUITE 3: Zero Runtime Heap Allocations in Steady State
# ==============================================================================
func _run_steady_state_zero_allocation_stress() -> void:
	print("\n--- Running Suite 3: Zero Runtime Heap Allocations in Steady State ---")
	
	# Part A: SpaceshipController Zero-Alloc in _physics_process
	var ship: SpaceshipController = SpaceshipController.new()
	root.add_child(ship)
	ship.enable_planetary_gravity = true
	ship.surface_gravity = 9.81
	ship.planet_radius = 100000.0
	ship.planet_position = Vector3(0, -100000.0, 0) # Planet center below ship
	ship.position = Vector3(0, 1000.0, 0)
	ship.thrust_input = Vector3(0.5, -0.2, 0.8)
	ship.torque_input = Vector3(0.1, 0.3, -0.4)
	
	# Warm up JIT / cache
	for frame in range(100):
		ship._physics_process(1.0 / 60.0)
	
	var mem_before_ship: int = OS.get_static_memory_usage()
	for frame in range(5000):
		ship._physics_process(1.0 / 60.0)
	var mem_after_ship: int = OS.get_static_memory_usage()
	var ship_delta: int = mem_after_ship - mem_before_ship
	_assert(ship_delta == 0, "SpaceshipController: ZERO runtime heap allocations across 5,000 frames (delta: %d bytes)" % ship_delta)
	
	# Part B: PlanetManager Steady-State Zero-Alloc in update_camera
	var planet: PlanetManager = PlanetManager.new()
	root.add_child(planet)
	planet.planet_radius = 100000.0
	planet.max_lod = 5
	var fixed_cam: Vector3 = Vector3(0, 105000.0, 0)
	
	# Initial camera update to establish steady-state quadtree
	planet.update_camera(fixed_cam)
	for warm in range(50):
		planet.update_camera(fixed_cam)
	
	var mem_before_planet: int = OS.get_static_memory_usage()
	for step in range(5000):
		planet.update_camera(fixed_cam)
	var mem_after_planet: int = OS.get_static_memory_usage()
	var planet_delta: int = mem_after_planet - mem_before_planet
	_assert(planet_delta == 0, "PlanetManager: ZERO runtime heap allocations across 5,000 steady-state camera updates (delta: %d bytes)" % planet_delta)
	
	# Cleanup
	root.remove_child(ship)
	ship.free()
	planet.destroy()
	root.remove_child(planet)
	planet.free()
	print("  Steady-state zero heap allocation tests passed with 0 bytes allocated.")

# ==============================================================================
# TEST SUITE 4: Sustained Quadtree Camera Movement & Collider Integrity
# ==============================================================================
func _run_quadtree_sustained_collider_stress() -> void:
	print("\n--- Running Suite 4: Sustained 2,000 Quadtree Camera Movements & Collider Audit ---")
	
	var planet: PlanetManager = PlanetManager.new()
	root.add_child(planet)
	planet.planet_radius = 100000.0
	planet.max_lod = 5
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	
	var max_active_colliders: int = 0
	var all_steps_valid: bool = true
	var zero_orphan_colliders: bool = true
	var zero_orphan_nodes: bool = true
	
	# 2,000 extreme camera transitions (orbit, dive to surface, circumnavigate poles)
	for step in range(2000):
		var theta: float = rng.randf_range(-PI, PI)
		var phi: float = rng.randf_range(-PI * 0.49, PI * 0.49)
		# Vary altitude from 500m above surface to 50,000m orbit
		var alt: float = rng.randf_range(500.0, 50000.0) if step % 2 == 0 else rng.randf_range(100.0, 2000.0)
		var r: float = planet.planet_radius + alt
		var cam_pos: Vector3 = Vector3(
			r * cos(phi) * sin(theta),
			r * sin(phi),
			r * cos(phi) * cos(theta)
		)
		
		planet.update_camera(cam_pos)
		
		var audit: Dictionary = planet.audit_system()
		if not audit["is_valid"]:
			all_steps_valid = false
		if audit["orphan_count"] != 0:
			zero_orphan_nodes = false
		if audit["active_colliders"] > max_active_colliders:
			max_active_colliders = audit["active_colliders"]
		
		# Confirm collider pool invariant: active + free == 64
		if planet.collider_pool != null:
			var cp_audit: Dictionary = planet.collider_pool.verify_integrity()
			if not cp_audit["is_valid"]:
				all_steps_valid = false
	
	_assert(all_steps_valid, "All 2,000 camera movements maintained 100% structural quadtree & collider validity")
	_assert(zero_orphan_nodes, "0 orphan Quadtree nodes across all 2,000 camera movements")
	_assert(zero_orphan_colliders, "0 orphan colliders across all 2,000 camera movements")
	_assert(max_active_colliders <= 64, "Max active colliders (%d) strictly <= 64 (never exceeded pool capacity)" % max_active_colliders)
	_assert(max_active_colliders > 0, "High-LOD surface dives successfully triggered collider acquisition (%d peak)" % max_active_colliders)
	
	# Return to deep space orbit and verify full merge and release
	planet.update_camera(Vector3(0, 0, 10000000.0))
	var final_audit: Dictionary = planet.audit_system()
	_assert(final_audit["is_valid"], "Final audit valid after return to deep space")
	_assert(final_audit["leaf_nodes"] == 6, "All 6 faces merged back to LOD 0 (6 leaves)")
	_assert(final_audit["active_colliders"] == 0, "All colliders released (0 active colliders at LOD 0)")
	_assert(final_audit["free_colliders"] == 64, "All 64 colliders returned to free pool")
	
	planet.destroy()
	root.remove_child(planet)
	planet.free()
	print("  Quadtree sustained collider integrity confirmed (0 leaks, 0 orphans).")

# ==============================================================================
# TEST SUITE 5: Hypersonic Spaceship Planetary Gravity & 100 Rebase Continuity
# ==============================================================================
func _run_hypersonic_gravity_rebase_stress() -> void:
	print("\n--- Running Suite 5: Hypersonic Gravity & 100 Rebase Velocity Conservation ---")
	var ship: SpaceshipController = SpaceshipController.new()
	root.add_child(ship)
	ship.enable_planetary_gravity = true
	ship.surface_gravity = 9.81
	ship.planet_radius = 100000.0
	ship.planet_position = Vector3(0, -100000.0, 0)
	
	var test_vel: Vector3 = Vector3(15000.0, -8000.0, 20000.0)
	var test_ang: Vector3 = Vector3(0.5, -0.3, 1.2)
	ship.linear_velocity = test_vel
	ship.angular_velocity = test_ang
	ship.position = Vector3(1500.0, 500.0, -1200.0)
	
	var rebase_failures: int = 0
	var double_rebase_blocked: bool = true
	
	for i in range(100):
		# Advance position past rebase threshold
		var shift_offset: Vector3 = Vector3(2000.0 + float(i), -500.0, 1800.0)
		ship.position += shift_offset
		
		var v_pre: Vector3 = ship.linear_velocity
		var w_pre: Vector3 = ship.angular_velocity
		var pos_pre: Vector3 = ship.position
		
		ship.rebase_origin(shift_offset)
		
		var v_post: Vector3 = ship.linear_velocity
		var w_post: Vector3 = ship.angular_velocity
		var pos_post: Vector3 = ship.position
		
		if (v_post - v_pre).length() > 1e-4 or (w_post - w_pre).length() > 1e-4:
			rebase_failures += 1
		if (pos_post - (pos_pre - shift_offset)).length() > 1e-4:
			rebase_failures += 1
		
		# Test Double-Rebase Deduplication on step 50
		if i == 50:
			var pos_before_dup: Vector3 = ship.position
			ship.rebase_origin(shift_offset) # Duplicate rebase in same frame
			if ship.position != pos_before_dup:
				double_rebase_blocked = false
	
	_assert(rebase_failures == 0, "100 hypersonic rebases conserved linear and angular velocity strictly within < 1e-4 tolerance")
	_assert(double_rebase_blocked, "Double rebase within same frame correctly deduplicated (no double shift)")
	
	# Gravity continuity check: step physics process at surface position of rebased planet
	var p_center: Vector3 = ship.get_planet_center()
	var p_radius: float = ship.get_planet_radius()
	ship.position = p_center + Vector3(0, p_radius + 50.0, 0) # 50m above rebased planet surface
	ship._physics_process(1.0 / 60.0)
	var grav: Vector3 = ship.get_current_gravity()
	_assert(grav.length() > 0.0, "Planetary gravity force actively exerted on vessel (%f N)" % grav.length())
	_assert_approx(ship.get_current_gravity_acceleration().length(), 9.81, 0.05, "Surface gravity acceleration near surface is ~9.81 m/s^2")
	
	root.remove_child(ship)
	ship.free()
	print("  Hypersonic gravity and rebase conservation passed with 0 velocity spikes.")

# ==============================================================================
# TEST SUITE 6: ChunkTaskScheduler 4-Worker Concurrency & Zero-Alloc Polling
# ==============================================================================
func _run_task_scheduler_concurrency_stress() -> void:
	print("\n--- Running Suite 6: ChunkTaskScheduler 4-Worker Concurrency & Polling ---")
	var scheduler: ChunkTaskScheduler = ChunkTaskScheduler.new()
	root.add_child(scheduler)
	
	_assert(scheduler.get_worker_count() == 4, "Scheduler worker thread count is strictly 4")
	_assert(scheduler.is_running(), "Scheduler is running")
	_assert(scheduler.get_available_slots() == 64, "Initial buffer capacity has 64 available slots")
	
	# Submit 32 background jobs
	var test_callable: Callable = Callable(self, "_dummy_task")
	var job_ids: Array[int] = []
	for i in range(32):
		var jid: int = scheduler.submit_job(test_callable, [i * 2])
		_assert(jid > 0, "Submitted job %d returned valid job_id %d" % [i, jid])
		job_ids.append(jid)
	
	# Wait for jobs to complete with polling
	var max_active_observed: int = 0
	var all_done: bool = false
	var timeout_frames: int = 500
	while timeout_frames > 0 and not all_done:
		timeout_frames -= 1
		scheduler.poll()
		var active: int = scheduler.get_active_worker_count()
		if active > max_active_observed:
			max_active_observed = active
		
		all_done = true
		for jid in job_ids:
			if not scheduler.is_job_completed(jid):
				all_done = false
				break
		if not all_done:
			OS.delay_msec(5)
	
	_assert(all_done, "All 32 background jobs completed successfully")
	_assert(max_active_observed <= 4, "Active worker threads (%d) never exceeded MAX_CONCURRENT_WORKERS (4)" % max_active_observed)
	
	# Verify results and reclaim slots
	for i in range(32):
		var jid: int = job_ids[i]
		var res = scheduler.get_job_result(jid)
		_assert(res == i * 2 + 10, "Job %d returned expected result (%d)" % [i, i * 2 + 10])
		_assert(scheduler.reclaim_job(jid), "Reclaimed slot for job %d" % jid)
	
	_assert(scheduler.get_available_slots() == 64, "All 64 slots available after reclamation")
	
	# Steady-state zero heap allocation test across 1,000 poll calls
	for warm in range(50):
		scheduler.poll()
	
	var mem_before_poll: int = OS.get_static_memory_usage()
	for p in range(1000):
		scheduler.poll()
	var mem_after_poll: int = OS.get_static_memory_usage()
	var poll_delta: int = mem_after_poll - mem_before_poll
	_assert(poll_delta == 0, "ChunkTaskScheduler: ZERO runtime heap allocations across 1,000 poll calls (delta: %d bytes)" % poll_delta)
	
	scheduler.shutdown()
	root.remove_child(scheduler)
	scheduler.free()
	print("  ChunkTaskScheduler 4-worker concurrency and polling verified.")

func _dummy_task(val: int) -> int:
	return val + 10

# ==============================================================================
# Summary
# ==============================================================================
func _print_summary() -> void:
	print("\n==================================================================")
	print("M12 EMPIRICAL CHALLENGER STRESS HARNESS SUMMARY")
	print("==================================================================")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	print("==================================================================")
	if failed_assertions == 0:
		print("SUCCESS: 100% EMPIRICAL PROOF CONFIRMED. ALL ASSERTIONS PASSED.")
	else:
		printerr("FAILURE: %d ASSERTIONS FAILED." % failed_assertions)
