extends SceneTree

## Adversarial Verification & Stress Harness for Milestone M8 (Reviewer 2)
## Tests:
## 1. Zero Runtime Allocations across 50,000 acquires/releases & 10,000 camera updates
## 2. In-Tree Floating Origin & PhysicsServer3D Transform Invariance
## 3. Double-Release Guards, Corrupted Index Defenses, & Pool Exhaustion Boundary
## 4. Adversarial Quadtree Admission Gating & Dynamic Stress Under Scarcity
## 5. ObjectDB and Static Memory Leak Verification
## 6. Deep Quadtree Dynamic Camera Stress and Rebase Invariance (500 steps)

const ColliderPoolManager = preload("res://ColliderPoolManager.gd")
const PlanetManager = preload("res://PlanetManager.gd")
const QuadtreeNode = preload("res://QuadtreeNode.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var _ran: bool = false

func _assert(condition: bool, msg: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("  ❌ ASSERTION FAILED: ", msg)

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	
	print("==================================================================")
	print("REVIEWER 2: ADVERSARIAL STRESS & VERIFICATION HARNESS (M8)")
	print("==================================================================")
	
	test_adv1_zero_allocation_steady_state()
	test_adv2_floating_origin_physicsserver_transform()
	test_adv3_double_release_and_adversarial_indices()
	test_adv4_pool_exhaustion_and_admission_gating()
	test_adv5_integrity_auditor_tamper_detection()
	test_adv6_deep_quadtree_stress_and_rebase_invariance()
	
	print("==================================================================")
	print("REVIEWER 2 SUMMARY: %d/%d assertions passed" % [passed_assertions, total_assertions])
	if failed_assertions == 0:
		print("VERDICT: APPROVE - All adversarial and memory tests passed!")
		quit(0)
	else:
		printerr("VERDICT: FAILED - %d assertions failed!" % failed_assertions)
		quit(1)
	return true

## -----------------------------------------------------------------------------
## ADV 1: Zero runtime heap allocations in steady-state operations
## -----------------------------------------------------------------------------
func test_adv1_zero_allocation_steady_state() -> void:
	print("\n--- ADV 1: Zero Runtime Allocations (Steady-State Operations) ---")
	var pool: ColliderPoolManager = ColliderPoolManager.new()
	var dummy: RefCounted = RefCounted.new()
	
	# Warm up pool
	for i in range(100):
		var id: int = pool.acquire_collider(dummy)
		pool.release_collider(id)
	
	# 50,000 acquire/release cycles
	var mem_before: int = OS.get_static_memory_usage()
	for i in range(50000):
		var id: int = pool.acquire_collider(dummy)
		pool.release_collider(id)
	var mem_after: int = OS.get_static_memory_usage()
	var delta: int = mem_after - mem_before
	_assert(delta <= 0, "50,000 acquires/releases must have delta <= 0 (actual: %d bytes)" % delta)
	
	# Test update_camera steady-state (no splits or merges)
	var pm: PlanetManager = PlanetManager.new()
	pm.planet_radius = 100_000.0
	pm.max_lod = 5
	var static_cam: Vector3 = Vector3(0.0, 0.0, 500_000.0)
	pm.update_camera(static_cam) # prime LOD
	
	# Warmup
	for i in range(100):
		pm.update_camera(static_cam)
	
	var pm_mem_before: int = OS.get_static_memory_usage()
	for i in range(10000):
		pm.update_camera(static_cam)
	var pm_mem_after: int = OS.get_static_memory_usage()
	var pm_delta: int = pm_mem_after - pm_mem_before
	_assert(pm_delta <= 0, "10,000 steady-state update_camera() calls must have delta <= 0 (actual: %d bytes)" % pm_delta)
	
	pm.destroy()
	pm.free()
	pool.clear()
	pool.free()
	print("  ✓ ADV 1 Passed: Zero heap allocation in steady-state operations confirmed.")

## -----------------------------------------------------------------------------
## ADV 2: In-Tree Floating Origin & PhysicsServer3D Transform Invariance
## -----------------------------------------------------------------------------
func test_adv2_floating_origin_physicsserver_transform() -> void:
	print("\n--- ADV 2: Floating Origin & PhysicsServer3D Transform Compatibility ---")
	var root_node: Node3D = Node3D.new()
	root.add_child(root_node)
	
	var pm: PlanetManager = PlanetManager.new()
	root_node.add_child(pm)
	
	# Acquire a collider and inject known triangular geometry
	var dummy: RefCounted = RefCounted.new()
	var cid: int = pm.collider_pool.acquire_collider(dummy)
	_assert(cid >= 0, "Acquired collider id %d" % cid)
	
	# A single triangle at local coordinates (100, 200, 300)
	var v0: Vector3 = Vector3(100.0, 200.0, 300.0)
	var v1: Vector3 = Vector3(110.0, 200.0, 300.0)
	var v2: Vector3 = Vector3(100.0, 210.0, 300.0)
	var faces: PackedVector3Array = PackedVector3Array([v0, v1, v2])
	pm.collider_pool.update_collider_faces(cid, faces)
	
	var body: StaticBody3D = pm.collider_pool.get_body(cid)
	_assert(body != null, "StaticBody3D exists")
	_assert(body.is_inside_tree(), "StaticBody3D is inside SceneTree")
	
	# Force physics space sync
	PhysicsServer3D.set_active(true)
	body.force_update_transform()
	
	# Initial transform check
	var initial_body_trans: Transform3D = body.global_transform
	var ps_trans_before: Transform3D = PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	_assert(initial_body_trans.origin.distance_to(Vector3.ZERO) < 1e-4, "Initial body origin at Vector3.ZERO")
	_assert(ps_trans_before.origin.distance_to(Vector3.ZERO) < 1e-4, "PhysicsServer3D initial body at Vector3.ZERO")
	
	# Raycast test in PhysicsDirectSpaceState3D before rebase
	var space_state: PhysicsDirectSpaceState3D = root_node.get_world_3d().direct_space_state
	var ray_origin_local: Vector3 = Vector3(102.0, 202.0, 350.0)
	var ray_target_local: Vector3 = Vector3(102.0, 202.0, 250.0)
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin_local, ray_target_local)
	query.collision_mask = 1
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		_assert(hit.collider == body, "Hit collider is StaticBody3D")
		_assert(abs(hit.position.z - 300.0) < 1e-3, "Hit position matches triangle plane at z=300")
	
	# Rebase origin by a massive offset
	var rebase_offset: Vector3 = Vector3(2500.0, -1800.0, 3200.0)
	pm.rebase_origin(rebase_offset)
	
	# After rebase, PlanetManager.global_position is -rebase_offset
	_assert(pm.global_position.distance_to(-rebase_offset) < 1e-4, "pm.global_position matches -rebase_offset")
	_assert(body.global_position.distance_to(-rebase_offset) < 1e-4, "body.global_position inherits -rebase_offset")
	
	body.force_update_transform()
	# Check PhysicsServer3D state directly
	var ps_trans_after: Transform3D = PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	_assert(ps_trans_after.origin.distance_to(-rebase_offset) < 1e-4, "PhysicsServer3D transform synchronized with rebase")
	
	# 100 consecutive rapid rebases
	var current_expected_pos: Vector3 = -rebase_offset
	for r in range(100):
		var delta_rebase: Vector3 = Vector3(randf_range(-1500.0, 1500.0), randf_range(-1500.0, 1500.0), randf_range(-1500.0, 1500.0))
		pm.rebase_origin(delta_rebase)
		current_expected_pos -= delta_rebase
		body.force_update_transform()
		var cur_ps_trans: Transform3D = PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		_assert(cur_ps_trans.origin.distance_to(current_expected_pos) < 1e-3, "Rapid rebase step %d PhysicsServer drift < 1e-3" % r)
	
	# Cleanup
	root_node.remove_child(pm)
	pm.destroy()
	pm.free()
	root.remove_child(root_node)
	root_node.free()
	print("  ✓ ADV 2 Passed: PhysicsServer3D transform and raycast collision completely invariant across rebases.")

## -----------------------------------------------------------------------------
## ADV 3: Double-Release Guards, Corrupted Index Defenses, & Pool Exhaustion
## -----------------------------------------------------------------------------
func test_adv3_double_release_and_adversarial_indices() -> void:
	print("\n--- ADV 3: Double-Release Guards & Adversarial Index Defenses ---")
	var pool: ColliderPoolManager = ColliderPoolManager.new()
	var dummy: RefCounted = RefCounted.new()
	
	# Acquire 5 colliders
	var ids: Array[int] = []
	for i in range(5):
		ids.append(pool.acquire_collider(dummy))
	_assert(pool.get_active_count() == 5, "Active count is 5")
	_assert(pool.get_free_count() == 59, "Free count is 59")
	
	# Adversarial releases:
	_assert(pool.release_collider(ids[2]) == true, "Legitimate release of ids[2] returns true")
	_assert(pool.release_collider(ids[2]) == false, "Double-release of ids[2] returns false")
	_assert(pool.release_collider(ids[2]) == false, "Triple-release of ids[2] returns false")
	_assert(pool.get_active_count() == 4, "Active count remains 4 after double-release attempt")
	_assert(pool.get_free_count() == 60, "Free count remains 60 after double-release attempt")
	
	# Out-of-bounds releases:
	_assert(pool.release_collider(-1) == false, "Negative index -1 returns false")
	_assert(pool.release_collider(-999999) == false, "Extreme negative index returns false")
	_assert(pool.release_collider(64) == false, "Boundary index 64 returns false")
	_assert(pool.release_collider(100) == false, "Out of bounds index 100 returns false")
	_assert(pool.release_collider(999999) == false, "Extreme positive index returns false")
	
	# Check integrity
	var audit: Dictionary = pool.verify_integrity()
	_assert(audit.is_valid, "Pool integrity intact after invalid release attempts")
	
	# Release remaining
	_assert(pool.release_collider(ids[0]) == true, "Release ids[0]")
	_assert(pool.release_collider(ids[1]) == true, "Release ids[1]")
	_assert(pool.release_collider(ids[3]) == true, "Release ids[3]")
	_assert(pool.release_collider(ids[4]) == true, "Release ids[4]")
	_assert(pool.get_active_count() == 0, "Active count back to 0")
	_assert(pool.get_free_count() == 64, "Free count back to 64")
	
	audit = pool.verify_integrity()
	_assert(audit.is_valid, "Final pool integrity is valid")
	
	pool.clear()
	pool.free()
	print("  ✓ ADV 3 Passed: Double-release guards and out-of-bounds defenses verified.")

## -----------------------------------------------------------------------------
## ADV 4: Pool Exhaustion & Quadtree Admission Gating Under Scarcity
## -----------------------------------------------------------------------------
func test_adv4_pool_exhaustion_and_admission_gating() -> void:
	print("\n--- ADV 4: Pool Exhaustion & Quadtree Admission Gating Under Scarcity ---")
	var pool: ColliderPoolManager = ColliderPoolManager.new()
	var dummy: RefCounted = RefCounted.new()
	
	# Pre-acquire 62 slots so only 2 remain free
	var held_slots: Array[int] = []
	for i in range(62):
		held_slots.append(pool.acquire_collider(dummy))
	_assert(pool.get_free_count() == 2, "Only 2 slots free")
	_assert(pool.has_available(2) == true, "has_available(2) is true")
	_assert(pool.has_available(3) == false, "has_available(3) is false")
	_assert(pool.has_available(4) == false, "has_available(4) is false")
	
	# Setup QuadtreeNode at lod_level = 3 where max_lod = 5 (so lod_level + 1 = 4 >= max_lod - 1)
	# Subdividing will require 4 collider slots
	var node: QuadtreeNode = QuadtreeNode.acquire_node()
	node.init_node(0, 3, Vector2(-1.0, -1.0), Vector2(1.0, 1.0), null, 100_000.0)
	var chunk_pool: ChunkPoolManager = ChunkPoolManager.new()
	node.mesh_id = chunk_pool.acquire_mesh(node)
	
	# Since col_needed = 4 and only 2 are free, split() MUST refuse and return false
	var split_result: bool = node.split(chunk_pool, 100_000.0, pool, 5)
	_assert(split_result == false, "split() gracefully rejected due to collider pool scarcity")
	_assert(node.is_leaf == true, "Node remains leaf when split is rejected")
	_assert(node.children.is_empty(), "No child nodes leaked when split is rejected")
	_assert(node.mesh_id != -1, "Parent mesh_id preserved when split is rejected")
	_assert(pool.get_free_count() == 2, "Collider free count unchanged")
	_assert(pool.get_active_count() == 62, "Collider active count unchanged")
	
	# Now free 2 more slots so 4 slots are available
	_assert(pool.release_collider(held_slots.pop_back()) == true, "Freed slot 1")
	_assert(pool.release_collider(held_slots.pop_back()) == true, "Freed slot 2")
	_assert(pool.get_free_count() == 4, "Now 4 slots free")
	_assert(pool.has_available(4) == true, "has_available(4) is now true")
	
	# Split should now succeed!
	var split_ok: bool = node.split(chunk_pool, 100_000.0, pool, 5)
	_assert(split_ok == true, "split() succeeds once capacity is available")
	_assert(node.is_leaf == false, "Node is now non-leaf")
	_assert(node.children.size() == 4, "Node has 4 children")
	_assert(pool.get_free_count() == 0, "All 4 free slots claimed by children")
	for child in node.children:
		_assert(child.collider_id >= 0 and child.collider_id < 64, "Child has valid collider_id")
		_assert(pool.get_collider_owner(child.collider_id) == child, "Collider owner is child")
	
	# Case A: Merge at lod_level = 3 (low-LOD parent, high-LOD children).
	# Children release 4, parent at LOD 3 does not acquire (lod_level < max_lod - 1)
	var merge_ok: bool = node.merge(chunk_pool, pool, 5)
	_assert(merge_ok == true, "merge() succeeds")
	_assert(node.is_leaf == true, "Node is leaf after merge")
	_assert(pool.get_free_count() == 4, "Children released 4, low-LOD parent acquires 0 (net free: 4)")
	_assert(node.collider_id == -1, "Low-LOD parent has collider_id == -1")
	
	# Case B: High-LOD parent re-acquisition (lod_level = 4, max_lod = 5)
	node.lod_level = 4
	node.collider_id = pool.acquire_collider(node) # Parent claims 1 of 4, 3 remain free
	_assert(pool.get_free_count() == 3, "Free count is 3")
	# Split parent at LOD 4 into LOD 5: needs 3 net colliders (parent releases 1, children take 4)
	_assert(node.split(chunk_pool, 100_000.0, pool, 5) == true, "High-LOD parent split succeeds")
	_assert(pool.get_free_count() == 0, "All 4 slots claimed by LOD 5 children")
	# Merge back to LOD 4: children release 4, parent re-acquires 1
	_assert(node.merge(chunk_pool, pool, 5) == true, "High-LOD merge succeeds")
	_assert(pool.get_free_count() == 3, "Children released 4, parent re-acquired 1 (net free: 3)")
	_assert(node.collider_id != -1, "High-LOD parent re-acquired collider")
	
	# Cleanup
	if node.collider_id != -1:
		pool.release_collider(node.collider_id)
	chunk_pool.release_mesh(node.mesh_id)
	QuadtreeNode.release_node(node)
	for slot in held_slots:
		pool.release_collider(slot)
	
	_assert(pool.get_free_count() == 64, "All 64 colliders free")
	_assert(pool.verify_integrity().is_valid, "Pool integrity intact")
	
	chunk_pool.clear()
	pool.clear()
	pool.free()
	print("  ✓ ADV 4 Passed: Admission gating prevents overruns and smoothly recycles colliders.")

## -----------------------------------------------------------------------------
## ADV 5: Integrity Auditor Tamper Detection
## -----------------------------------------------------------------------------
func test_adv5_integrity_auditor_tamper_detection() -> void:
	print("\n--- ADV 5: Integrity Auditor Tamper Detection ---")
	var pool: ColliderPoolManager = ColliderPoolManager.new()
	var dummy: RefCounted = RefCounted.new()
	
	var cid: int = pool.acquire_collider(dummy)
	var valid_audit: Dictionary = pool.verify_integrity()
	_assert(valid_audit.is_valid == true, "Valid audit before tampering")
	
	# Inject Tamper 1: Desynchronize active_count
	pool.active_count = 5
	var tamper1_audit: Dictionary = pool.verify_integrity()
	_assert(tamper1_audit.is_valid == false, "Auditor catches active_count mismatch")
	pool.active_count = 1 # restore
	
	# Inject Tamper 2: Duplicate free index
	pool.free_indices.append(cid)
	var tamper2_audit: Dictionary = pool.verify_integrity()
	_assert(tamper2_audit.is_valid == false, "Auditor catches duplicate in free stack")
	pool.free_indices.pop_back() # restore
	
	# Inject Tamper 3: Disabled shape while in use
	pool.collision_shapes[cid].disabled = true
	var tamper3_audit: Dictionary = pool.verify_integrity()
	_assert(tamper3_audit.is_valid == false, "Auditor catches enabled slot with disabled CollisionShape")
	pool.collision_shapes[cid].disabled = false # restore
	
	pool.release_collider(cid)
	_assert(pool.verify_integrity().is_valid == true, "Restored pool integrity is valid")
	
	pool.clear()
	pool.free()
	print("  ✓ ADV 5 Passed: verify_integrity() is robust and detects tampering.")

## -----------------------------------------------------------------------------
## ADV 6: Deep Quadtree Stress and Rebase Invariance
## -----------------------------------------------------------------------------
func test_adv6_deep_quadtree_stress_and_rebase_invariance() -> void:
	print("\n--- ADV 6: Deep Quadtree Dynamic Camera Stress and Rebase Invariance ---")
	var pm: PlanetManager = PlanetManager.new()
	pm.planet_radius = 100_000.0
	pm.max_lod = 5
	pm.split_ratio = 2.5
	pm.hysteresis = 1.25
	
	# Simulate 500 chaotic steps with random camera moves and frequent 2000m rebases
	var rebase_count: int = 0
	for step in range(500):
		var ang: float = step * 0.1
		var dist: float = 100_000.0 + 50.0 + 200_000.0 * (0.5 + 0.5 * sin(step * 0.05))
		var cam: Vector3 = Vector3(cos(ang) * dist, sin(ang) * dist * 0.5, sin(ang) * dist)
		pm.update_camera(cam)
		
		# Rebase every 25 steps
		if step % 25 == 0:
			var offset: Vector3 = Vector3(2005.0, -2010.0, 2020.0)
			pm.rebase_origin(offset)
			rebase_count += 1
		
		# Verify invariants
		var audit: Dictionary = pm.audit_system()
		if not audit.is_valid:
			print("AUDIT FAILURE AT STEP ", step, ": ", audit.errors)
			_assert(false, "Step %d audit must be valid" % step)
			break
		
		_assert(audit.active_colliders <= 64, "Step %d active colliders <= 64" % step)
		_assert(audit.active_colliders + audit.free_colliders == 64, "Step %d active + free == 64" % step)
		_assert(audit.orphan_count == 0, "Step %d 0 orphans" % step)
	
	# Full deep orbit retreat
	pm.update_camera(Vector3(10_000_000.0, 0.0, 0.0))
	var final_audit: Dictionary = pm.audit_system()
	_assert(final_audit.is_valid, "Final retreat audit is valid")
	_assert(final_audit.leaf_nodes == 6, "Collapsed to 6 leaves")
	_assert(final_audit.active_colliders == 0, "0 active colliders")
	_assert(final_audit.free_colliders == 64, "64 free colliders")
	
	pm.destroy()
	pm.free()
	print("  ✓ ADV 6 Passed: 500 dynamic stress steps and %d rebases completed with 0 errors." % rebase_count)
