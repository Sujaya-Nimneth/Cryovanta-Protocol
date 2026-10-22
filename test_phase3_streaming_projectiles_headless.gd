extends SceneTree

## Phase 3 headless verification suite for Cryovanta Protocol.
## Run with: godot --headless -s test_phase3_streaming_projectiles_headless.gd

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

var PlanetStreamerClass = null
var ProjectilePoolManagerClass = null
var ComputeChunkDispatcherClass = null
var SpaceshipWeaponSystemClass = null
var PlanetManagerClass = null
var ColliderPoolManagerClass = null
var ChunkTaskSchedulerClass = null
var TerrainMeshBuilderClass = null
var SpaceshipControllerClass = null

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 3 Headless Verification Suite (Tiers 1-5)")
	print("==================================================================")
	await process_frame
	_load_classes()
	await _run_tier_1()
	await _run_tier_2()
	_run_tier_3()
	await _run_tier_4()
	await _run_hardening()
	_run_tier_5()
	_print_summary()
	quit(0 if failed_assertions == 0 else 1)

func _load_classes() -> void:
	PlanetStreamerClass = load("res://PlanetStreamer.gd")
	ProjectilePoolManagerClass = load("res://ProjectilePoolManager.gd")
	ComputeChunkDispatcherClass = load("res://ComputeChunkDispatcher.gd")
	SpaceshipWeaponSystemClass = load("res://SpaceshipWeaponSystem.gd")
	PlanetManagerClass = load("res://PlanetManager.gd")
	ColliderPoolManagerClass = load("res://ColliderPoolManager.gd")
	ChunkTaskSchedulerClass = load("res://ChunkTaskScheduler.gd")
	TerrainMeshBuilderClass = load("res://TerrainMeshBuilder.gd")
	SpaceshipControllerClass = load("res://SpaceshipController.gd")
	_start_test("Load Phase 3 classes")
	_assert(PlanetStreamerClass != null, "PlanetStreamer.gd failed to load")
	_assert(ProjectilePoolManagerClass != null, "ProjectilePoolManager.gd failed to load")
	_assert(ComputeChunkDispatcherClass != null, "ComputeChunkDispatcher.gd failed to load")
	_assert(SpaceshipWeaponSystemClass != null, "SpaceshipWeaponSystem.gd failed to load")
	_assert(PlanetManagerClass != null, "PlanetManager.gd failed to load")
	_assert(ColliderPoolManagerClass != null, "ColliderPoolManager.gd failed to load")
	_assert(ChunkTaskSchedulerClass != null, "ChunkTaskScheduler.gd failed to load")
	_assert(TerrainMeshBuilderClass != null, "TerrainMeshBuilder.gd failed to load")
	_assert(SpaceshipControllerClass != null, "SpaceshipController.gd failed to load")

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
	if condition:
		_pass()
	else:
		_fail(message)

func _assert_int(actual, expected, message: String) -> void:
	_assert(int(actual) == int(expected), "%s (expected %d, got %d)" % [message, int(expected), int(actual)])

func _assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assert(absf(actual - expected) <= tolerance, "%s (expected %.8f, got %.8f)" % [message, expected, actual])

func _assert_vec3(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> void:
	_assert(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func _print_summary() -> void:
	print("\n==================================================================")
	print("PHASE 3 TEST SUITE EXECUTION SUMMARY")
	print("==================================================================")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	print("==================================================================")
	if failed_assertions == 0:
		print("SUCCESS: All %d assertions passed with exit code 0!" % total_assertions)
	else:
		printerr("FAILURE: %d out of %d assertions failed!" % [failed_assertions, total_assertions])

func _make_planet(max_lod: int = 5) -> Node:
	var planet: Node = PlanetManagerClass.new()
	planet.planet_radius = 100_000.0
	planet.max_lod = max_lod
	get_root().add_child(planet)
	return planet

func _make_streamer(planet: Node, immediate: bool) -> Node:
	var streamer: Node = PlanetStreamerClass.new()
	get_root().add_child(streamer)
	streamer.setup(planet, null, immediate)
	return streamer

func _prepare_face_zero_high_lod(planet: Node) -> void:
	for step in range(5):
		planet.update_camera(Vector3(100_050.0, 0.0, 0.0))

func _wait_streamer(streamer: Node, max_frames: int = 600) -> bool:
	for frame in range(max_frames):
		streamer.task_scheduler.poll()
		var ready: bool = streamer.pending_jobs == 0
		if ready:
			for leaf in streamer.planet_manager.get_all_leaves():
				var mesh_id: int = leaf.mesh_id
				if mesh_id < 0 or mesh_id >= streamer.VISUAL_POOL_SIZE:
					ready = false
					break
				if streamer.mesh_loaded[mesh_id] == 0 or not streamer.visuals[mesh_id].visible:
					ready = false
					break
		if ready:
			return true
		await process_frame
	return false

func _dispose_planet_fixture(planet: Node, streamer: Node) -> void:
	if streamer != null:
		streamer.destroy()
		if streamer.get_parent() == get_root():
			get_root().remove_child(streamer)
		streamer.free()
	if planet != null:
		planet.destroy()
		if planet.get_parent() == get_root():
			get_root().remove_child(planet)
		planet.free()

func _leaf_origin(planet: Node, leaf) -> Vector3:
	return TerrainMeshBuilderClass.get_chunk_origin(leaf.face_index, leaf.uv_min, planet.planet_radius)

func _assert_leaf_alignment(planet: Node, streamer: Node, leaf) -> void:
	var mesh_id: int = leaf.mesh_id
	var origin: Vector3 = _leaf_origin(planet, leaf)
	_assert(mesh_id >= 0 and mesh_id < 256, "Leaf mesh_id is in the pre-allocated range")
	if mesh_id < 0 or mesh_id >= 256:
		return
	_assert(streamer.visuals[mesh_id].visible, "Active leaf visual is visible")
	_assert_vec3(streamer.visuals[mesh_id].position, origin, 1e-4, "MeshInstance3D origin matches sea_origin")
	var mesh: ArrayMesh = planet.chunk_pool.get_mesh(mesh_id)
	_assert_int(mesh.get_surface_count(), 1, "Pooled leaf mesh has one surface")
	if mesh.get_surface_count() != 1:
		return
	_assert_int(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 1156, "Pooled leaf mesh has 1156 vertices")
	if leaf.collider_id != -1:
		_assert_vec3(planet.collider_pool.get_collider_origin(leaf.collider_id), origin, 1e-4, "Collider origin matches sea_origin")
		_assert(planet.collider_pool.get_shape(leaf.collider_id).get_faces().size() > 0, "Collider has baked terrain faces")

func _run_tier_1() -> void:
	print("\n--- Tier 1: Live Quadtree-to-Mesh and Collider Streaming ---")
	_start_test("Tier 1.1: 256 pre-allocated MeshInstance3D slots")
	var planet: Node = _make_planet(5)
	var streamer: Node = _make_streamer(planet, false)
	_assert_int(streamer.visuals.size(), 256, "Streamer visual pool size")
	_assert_int(streamer.VISUAL_POOL_SIZE, 256, "VISUAL_POOL_SIZE")
	_assert_int(planet.chunk_pool.meshes.size(), 256, "ChunkPoolManager mesh pool size")
	for i in range(256):
		_assert(streamer.visuals[i] is MeshInstance3D, "Visual slot %d is a MeshInstance3D" % i)
		_assert(streamer.visuals[i].mesh == planet.chunk_pool.get_mesh(i), "Visual slot %d shares its pooled ArrayMesh" % i)

	_start_test("Tier 1.2: Asynchronous initial leaf completion")
	streamer.update_streamer(Vector3(0.0, 0.0, 5_000_000.0))
	_assert(await _wait_streamer(streamer), "Initial asynchronous streaming jobs completed")
	var leaves: Array = planet.get_all_leaves()
	_assert_int(leaves.size(), 6, "Initial six cube-face leaves")
	_assert_int(streamer.get_active_visual_count(), leaves.size(), "Active visuals equal initial leaves")
	for leaf in leaves:
		_assert_leaf_alignment(planet, streamer, leaf)
	var initial_audit: Dictionary = planet.audit_system()
	_assert(initial_audit["is_valid"], "Initial planet audit is valid")
	_assert_int(initial_audit["orphan_count"], 0, "Initial orphan count is zero")
	_assert_int(streamer.get_orphan_mesh_count(), 0, "Initial streamer orphan count is zero")

	_start_test("Tier 1.3: High-LOD leaves stream mesh and collider origins")
	_dispose_planet_fixture(planet, streamer)
	planet = _make_planet(4)
	streamer = _make_streamer(planet, true)
	var low_orbit: Vector3 = Vector3(100_050.0, 1_000.0, 1_000.0)
	for step in range(5):
		streamer.update_streamer(low_orbit)
	leaves = planet.get_all_leaves()
	var high_lod_count: int = 0
	for leaf in leaves:
		if leaf.lod_level >= planet.max_lod - 1:
			high_lod_count += 1
		_assert_leaf_alignment(planet, streamer, leaf)
	_assert(high_lod_count > 0, "Low orbit produced high-LOD leaves")
	_assert_int(planet.collider_pool.get_active_count(), high_lod_count, "Active collider count equals high-LOD leaves")
	_assert_int(streamer.get_active_visual_count(), leaves.size(), "Active visuals equal low-orbit leaves")
	_assert_int(streamer.get_orphan_mesh_count(), 0, "No orphan streamed meshes at low orbit")
	await physics_frame
	await physics_frame

	_start_test("Tier 1.4: Merge cancels pending jobs and resets hidden slots")
	_dispose_planet_fixture(planet, streamer)
	planet = _make_planet(4)
	streamer = _make_streamer(planet, false)
	var split_camera: Vector3 = Vector3(100_050.0, 1_000.0, 1_000.0)
	for step in range(5):
		streamer.update_streamer(split_camera)
	_assert(planet.get_all_leaves().size() > 6, "Async fixture starts from a split quadtree")
	var cancelled_before: int = streamer.cancelled_job_count
	var queued_before: int = streamer.queued_job_count
	OS.delay_msec(20)
	var queued_for_merge: bool = streamer.pending_jobs > 0
	streamer.update_streamer(Vector3(10_000_000.0, 0.0, 0.0))
	_assert(queued_for_merge, "LOD update queued work before the merge")
	_assert(streamer.cancelled_job_count > cancelled_before, "Merge cancelled at least one queued/running job")
	_assert(streamer.queued_job_count >= queued_before, "Queued job accounting remains monotonic")
	_assert(await _wait_streamer(streamer), "Merged streaming state settled")
	streamer.update_streamer(Vector3(10_000_000.0, 0.0, 0.0))
	_assert(await _wait_streamer(streamer), "Merged streaming state settled")
	leaves = planet.get_all_leaves()
	_assert_int(leaves.size(), 6, "Merge collapsed back to six leaves")
	_assert_int(streamer.get_active_visual_count(), 6, "Only six visuals remain visible after merge")
	_assert_int(streamer.get_orphan_mesh_count(), 0, "No orphan streamed meshes after merge")
	for i in range(256):
		if streamer.mesh_owners[i] == null:
			_assert(not streamer.visuals[i].visible, "Reset visual slot %d is hidden" % i)
			_assert_int(streamer.mesh_loaded[i], 0, "Reset visual slot %d is unloaded" % i)
	var final_audit: Dictionary = planet.audit_system()
	_assert(final_audit["is_valid"], "Post-merge planet audit is valid")
	_assert_int(final_audit["orphan_count"], 0, "Post-merge orphan count is zero")
	_assert_int(final_audit["active_meshes"], 6, "Post-merge active mesh count is six")
	_assert_int(final_audit["active_colliders"], 0, "Post-merge collider count is zero")
	_dispose_planet_fixture(planet, streamer)

func _configure_query(query: PhysicsRayQueryParameters3D, from: Vector3, to: Vector3) -> void:
	query.from = from
	query.to = to
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.hit_from_inside = true
	query.hit_back_faces = true

func _find_terrain_ray(faces: PackedVector3Array, origin: Vector3, space_state: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D) -> Dictionary:
	for triangle in range(faces.size() / 3):
		var a: Vector3 = faces[triangle * 3]
		var b: Vector3 = faces[triangle * 3 + 1]
		var c: Vector3 = faces[triangle * 3 + 2]
		var normal: Vector3 = (b - a).cross(c - a)
		if normal.length_squared() < 1e-8:
			continue
		normal = normal.normalized()
		var midpoint: Vector3 = (a + b + c) / 3.0
		for sign in [-1.0, 1.0]:
			var from: Vector3 = origin + midpoint + normal * 1_000.0 * sign
			var to: Vector3 = origin + midpoint - normal * 1_000.0 * sign
			_configure_query(query, from, to)
			var hit: Dictionary = space_state.intersect_ray(query)
			if not hit.is_empty():
				return {"hit": hit, "from": from, "to": to, "normal": normal}
	return {}

func _find_radial_radar_fixture(high_lod: Array, planet: Node, space_state: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D) -> Dictionary:
	for leaf in high_lod:
		var faces: PackedVector3Array = planet.collider_pool.get_shape(leaf.collider_id).get_faces()
		var origin: Vector3 = planet.collider_pool.get_collider_origin(leaf.collider_id)
		for triangle in range(faces.size() / 3):
			var midpoint: Vector3 = origin + (faces[triangle * 3] + faces[triangle * 3 + 1] + faces[triangle * 3 + 2]) / 3.0
			var radial_dir: Vector3 = (midpoint - planet.planet_center_offset).normalized()
			if radial_dir.length_squared() < 1e-12:
				continue
			for lift in [600.0, 550.0]:
				var ship_position: Vector3 = midpoint + radial_dir * lift
				_configure_query(query, ship_position, ship_position - radial_dir * 5_000.0)
				var hit: Dictionary = space_state.intersect_ray(query)
				if not hit.is_empty() and hit["collider"] is StaticBody3D:
					return {
						"ship_position": ship_position,
						"surface_position": hit["position"]
					}
	return {}

func _run_tier_2() -> void:
	print("\n--- Tier 2: Pre-Allocated 128-Slot Projectile Ring Buffer ---")
	_start_test("Tier 2.1: O(1) acquisition, exhaustion, and release")
	var pool: Node = ProjectilePoolManagerClass.new()
	get_root().add_child(pool)
	_assert_int(pool.POOL_SIZE, 128, "POOL_SIZE")
	_assert_int(pool.positions.size(), 128, "positions array size")
	_assert_int(pool.velocities.size(), 128, "velocities array size")
	_assert_int(pool.lifetimes.size(), 128, "lifetimes array size")
	_assert_int(pool.markers.size(), 128, "marker pool size")
	var acquired: Array[int] = []
	for i in range(128):
		var pid: int = pool.spawn_projectile(Vector3(float(i), 1.0, 2.0), Vector3.UP, 10.0)
		_assert(pid >= 0 and pid < 128, "Projectile acquisition %d returned a valid slot" % i)
		_assert(not acquired.has(pid), "Projectile slot %d is unique" % pid)
		acquired.append(pid)
	_assert_int(pool.active_count, 128, "All 128 slots active")
	_assert_int(pool.spawn_projectile(Vector3.ZERO, Vector3.ZERO), -1, "Exhausted spawn returns -1")
	_assert_int(pool.release_projectile(acquired[0]), true, "Release succeeds")
	_assert_int(pool.spawn_projectile(Vector3.ZERO, Vector3.ZERO), acquired[0], "Released slot is reused in O(1)")
	_assert_int(pool.release_projectile(-1), false, "Invalid release returns false")
	_assert_int(pool.release_projectile(128), false, "Out-of-range release returns false")
	_assert(pool.verify_integrity()["is_valid"], "Projectile pool integrity after churn")
	pool.clear()
	_assert_int(pool.active_count, 0, "clear() releases all projectiles")
	_assert(pool.verify_integrity()["is_valid"], "Projectile pool integrity after clear")

	_start_test("Tier 2.2: Zero-allocation projectile stepping")
	for i in range(16):
		pool.spawn_projectile(Vector3(0.0, 100_000.0 + float(i), 0.0), Vector3(100.0, -50.0, 25.0), 1_000_000.0)
	for i in range(200):
		pool.step_projectiles(0.016, null, Vector3.ZERO, 100_000.0, 9.81)
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(2_000):
		pool.step_projectiles(0.016, null, Vector3.ZERO, 100_000.0, 9.81)
	var memory_after: int = OS.get_static_memory_usage()
	_assert(memory_after - memory_before <= 0, "Steady-state projectile stepping has zero static memory growth")
	_assert(pool.verify_integrity()["is_valid"], "Projectile pool integrity after stepping")
	pool.clear()

	_start_test("Tier 2.3: Raycast impact against a baked ConcavePolygonShape3D")
	var collider_pool: Node = ColliderPoolManagerClass.new()
	get_root().add_child(collider_pool)
	var owner: RefCounted = RefCounted.new()
	var cid: int = collider_pool.acquire_collider(owner)
	_assert(cid >= 0, "Acquired a terrain collider")
	var uv_min: Vector2 = Vector2(-0.5, -0.5)
	var uv_max: Vector2 = Vector2(0.5, 0.5)
	var radius: float = 100_000.0
	var origin: Vector3 = TerrainMeshBuilderClass.get_chunk_origin(0, uv_min, radius)
	var faces: PackedVector3Array = TerrainMeshBuilderClass.build_collider_faces(
		0, 2, uv_min, uv_max, radius, 1337, 0.002, 500.0, 0, true
	)
	collider_pool.set_collider_origin(cid, origin)
	collider_pool.update_collider_faces(cid, faces)
	var body: StaticBody3D = collider_pool.get_body(cid)
	body.force_update_transform()
	PhysicsServer3D.set_active(true)
	await physics_frame
	await physics_frame
	var space_state: PhysicsDirectSpaceState3D = get_root().get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	var terrain_ray: Dictionary = _find_terrain_ray(faces, origin, space_state, query)
	_assert(not terrain_ray.is_empty(), "Physics oracle found a terrain triangle ray")
	if not terrain_ray.is_empty():
		var impact_id: int = pool.spawn_projectile(terrain_ray["from"], (terrain_ray["to"] - terrain_ray["from"]), 5.0)
		_assert(impact_id >= 0, "Spawned projectile toward terrain")
		var impacted: int = pool.step_projectiles(1.0, space_state)
		_assert_int(impacted, 1, "Projectile raycast detected one terrain impact")
		_assert_int(pool.active_count, 0, "Impacted projectile was auto-released")
		_assert(terrain_ray["hit"]["collider"] == body, "Impact ray hit the terrain StaticBody3D")
	_assert(pool.verify_integrity()["is_valid"], "Projectile integrity after impact")

	_start_test("Tier 2.4: Origin rebase preserves projectile velocity")
	var pid: int = pool.spawn_projectile(Vector3(2_000.0, 500.0, -300.0), Vector3(123.0, -45.0, 67.0), 20.0)
	var pid2: int = pool.spawn_projectile(Vector3(2_100.0, 600.0, -400.0), Vector3(-80.0, 25.0, 15.0), 20.0)
	var position_before: Vector3 = pool.positions[pid]
	var velocity_before: Vector3 = pool.velocities[pid]
	var lifetime_before: float = pool.lifetimes[pid]
	var shift: Vector3 = Vector3(2_000.0, 1_000.0, -500.0)
	var position2_before: Vector3 = pool.positions[pid2]
	pool.rebase_origin(shift)
	_assert_vec3(pool.positions[pid], position_before - shift, 1e-4, "Projectile position shifts by -offset")
	_assert_vec3(pool.positions[pid2], position2_before - shift, 1e-4, "All active projectiles shift by -offset")
	_assert_vec3(pool.velocities[pid], velocity_before, 1e-4, "Projectile velocity is continuous across rebase")
	_assert_approx(pool.lifetimes[pid], lifetime_before, 1e-6, "Projectile lifetime is unchanged across rebase")
	_assert(pool.verify_integrity()["is_valid"], "Projectile integrity after rebase")
	pool.clear()
	collider_pool.clear()
	get_root().remove_child(collider_pool)
	collider_pool.free()
	get_root().remove_child(pool)
	pool.free()

func _run_tier_3() -> void:
	print("\n--- Tier 3: Vulkan Compute Dispatcher and CPU Fallback ---")
	_start_test("Tier 3.1: Dispatch constants and std430 byte contract")
	var dispatcher = ComputeChunkDispatcherClass.new()
	_assert_int(dispatcher.WORKGROUP_X, 5, "WORKGROUP_X")
	_assert_int(dispatcher.WORKGROUP_Y, 5, "WORKGROUP_Y")
	_assert_int(dispatcher.WORKGROUP_Z, 1, "WORKGROUP_Z")
	_assert_int(dispatcher.VERTEX_STRIDE_BYTES, 32, "VERTEX_STRIDE_BYTES")
	_assert_int(dispatcher.VERTEX_COUNT, 1_156, "VERTEX_COUNT")
	_assert_int(dispatcher.STORAGE_BUFFER_SIZE_BYTES, 36_992, "STORAGE_BUFFER_SIZE_BYTES")
	_assert_int(dispatcher.STORAGE_BUFFER_SIZE_BYTES, dispatcher.VERTEX_STRIDE_BYTES * dispatcher.VERTEX_COUNT, "Storage buffer equals stride * count")
	_assert(dispatcher.get_dispatch_group_count() == Vector3i(5, 5, 1), "Dispatch contract is (5, 5, 1)")
	_assert_int(dispatcher.get_invocation_count(), 1_600, "Dispatch invocation count")

	_start_test("Tier 3.2: 36,992-byte PlanetVertex packing/unpacking parity")
	var mesh: ArrayMesh = TerrainMeshBuilderClass.build_mesh_cpu(
		0, 2, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100_000.0,
		1337, 0.002, 500.0, null, true, 2
	)
	var arrays: Array = mesh.surface_get_arrays(0)
	_assert_int(arrays[Mesh.ARRAY_VERTEX].size(), 1_156, "Reference CPU mesh has 1,156 vertices")
	var dispatcher_bytes: PackedByteArray = dispatcher.pack_std430_vertex_buffer(2)
	var expected_vertices: PackedVector3Array = TerrainMeshBuilderClass._vertices_pool[2].duplicate()
	var expected_normals: PackedVector3Array = TerrainMeshBuilderClass._normals_pool[2].duplicate()
	var expected_uvs: PackedVector2Array = TerrainMeshBuilderClass._uvs_pool[2].duplicate()
	_assert_int(dispatcher_bytes.size(), 36_992, "Packed buffer byte length")
	_assert(dispatcher.unpack_std430_vertex_buffer(dispatcher_bytes, 2), "Unpack accepts the exact buffer size")
	var bytes: PackedByteArray = dispatcher.last_vertex_buffer.duplicate()
	var packing_before: int = OS.get_static_memory_usage()
	for i in range(8):
		dispatcher.unpack_std430_vertex_buffer(bytes, 2)
	var packing_after: int = OS.get_static_memory_usage()
	_assert(packing_after - packing_before <= 0, "std430 unpacking reuses pre-allocated readback buffers")
	_assert(not dispatcher.unpack_std430_vertex_buffer(dispatcher_bytes.slice(0, 36_991), 2), "Unpack rejects a short buffer")
	var parity_ok: bool = true
	for i in range(1_156):
		var p: Vector4 = dispatcher.last_vertices[i]
		var n: Vector4 = dispatcher.last_normals[i]
		if p.distance_to(Vector4(expected_vertices[i].x, expected_vertices[i].y, expected_vertices[i].z, expected_uvs[i].x)) > 1e-5:
			parity_ok = false
		if n.distance_to(Vector4(expected_normals[i].x, expected_normals[i].y, expected_normals[i].z, expected_uvs[i].y)) > 1e-5:
			parity_ok = false
	_assert(parity_ok, "All 1,156 vertices, normals, and UVs round-trip through std430")
	_assert_approx(bytes.decode_float(0), expected_vertices[0].x, 1e-6, "First byte offset holds position.x")
	_assert_approx(bytes.decode_float(12), expected_uvs[0].x, 1e-6, "Twelfth byte offset holds uv.x")
	_assert_approx(bytes.decode_float(28), expected_uvs[0].y, 1e-6, "Twenty-eighth byte offset holds uv.y")

	_start_test("Tier 3.3: Headless CPU fallback dispatch")
	_assert(dispatcher.is_headless, "Headless renderer detected")
	_assert(dispatcher.get_effective_backend() == "cpu_fallback", "Effective backend is cpu_fallback")
	_assert(not dispatcher.fallback_reason.is_empty(), "Fallback reason is reported")
	var fallback_mesh: ArrayMesh = dispatcher.dispatch_chunk(
		0, 2, Vector2(-0.5, -0.5), Vector2(0.5, 0.5), 100_000.0,
		1337, 0.002, 500.0
	)
	_assert(fallback_mesh != null, "CPU fallback returned a mesh")
	_assert_int(fallback_mesh.get_surface_count(), 1, "Fallback mesh has one surface")
	_assert_int(fallback_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 1_156, "Fallback mesh has 1,156 vertices")
	_assert(dispatcher.get_effective_backend() == "cpu_fallback", "Backend remains deterministic after dispatch")
	dispatcher.shutdown()

func _run_tier_4() -> void:
	print("\n--- Tier 4: Spaceship Weapon and Surface Radar ---")
	_start_test("Tier 4.1: High-LOD streamed terrain fixture")
	var planet: Node = _make_planet(4)
	var streamer: Node = _make_streamer(planet, true)
	streamer.update_streamer(Vector3(10_000_000.0, 0.0, 0.0))
	_prepare_face_zero_high_lod(planet)
	streamer.update_streamer(Vector3(100_050.0, 1_000.0, 1_000.0))
	var leaves: Array = planet.get_all_leaves()
	var high_lod: Array = []
	for leaf in leaves:
		if leaf.collider_id != -1 and leaf.lod_level >= planet.max_lod - 1:
			high_lod.append(leaf)
	_assert(high_lod.size() > 0, "Synchronous streamer produced high-LOD terrain colliders")
	for leaf in high_lod:
		_assert_leaf_alignment(planet, streamer, leaf)
	_assert(planet.audit_system()["is_valid"], "High-LOD streamer audit is valid")
	await physics_frame
	await physics_frame

	_start_test("Tier 4.2: Projectile velocity inheritance and rebase continuity")
	var pool: Node = ProjectilePoolManagerClass.new()
	get_root().add_child(pool)
	var ship = SpaceshipControllerClass.new()
	ship.collision_layer = 0
	ship.collision_mask = 0
	ship.planet_manager = planet
	get_root().add_child(ship)
	var basis: Basis = Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, 0.2) * Basis(Vector3.BACK, 0.1)
	ship.global_transform = Transform3D(basis, Vector3(0.0, 0.0, 0.0))
	ship.linear_velocity = Vector3(100.0, 20.0, -30.0)
	var weapon = SpaceshipWeaponSystemClass.new()
	get_root().add_child(weapon)
	weapon.ship = ship
	weapon.projectile_pool = pool
	weapon.planet_manager = planet
	var pid: int = weapon.fire_projectile(Vector3(0.0, 0.0, -2.0), 800.0, 5.0)
	_assert(pid >= 0, "Weapon spawned a projectile")
	var expected_position: Vector3 = ship.global_transform * Vector3(0.0, 0.0, -2.0)
	var expected_velocity: Vector3 = ship.linear_velocity + (-ship.global_transform.basis.z) * 800.0
	_assert_vec3(pool.positions[pid], expected_position, 1e-4, "Projectile starts at the transformed muzzle")
	_assert_vec3(pool.velocities[pid], expected_velocity, 1e-4, "Projectile inherits ship velocity plus muzzle speed")
	var ship_position_before: Vector3 = ship.global_position
	var ship_velocity_before: Vector3 = ship.linear_velocity
	var projectile_position_before: Vector3 = pool.positions[pid]
	var projectile_velocity_before: Vector3 = pool.velocities[pid]
	var rebase: Vector3 = Vector3(2_000.0, 1_000.0, -500.0)
	ship.rebase_origin(rebase)
	pool.rebase_origin(rebase)
	_assert_vec3(ship.global_position, ship_position_before - rebase, 1e-4, "Ship position shifts across rebase")
	_assert_vec3(ship.linear_velocity, ship_velocity_before, 1e-4, "Ship velocity is continuous across rebase")
	_assert_vec3(pool.positions[pid], projectile_position_before - rebase, 1e-4, "Projectile position shifts with ship rebase")
	_assert_vec3(pool.velocities[pid], projectile_velocity_before, 1e-4, "Projectile velocity is continuous across rebase")
	_assert(weapon.get_radar_query() == weapon.get_radar_query(), "Radar reuses one PhysicsRayQueryParameters3D")

	_start_test("Tier 4.3: Radar altimeter against high-LOD collider geometry")
	for leaf in high_lod:
		planet.collider_pool.get_body(leaf.collider_id).force_update_transform()
	await physics_frame
	await physics_frame
	var space_state: PhysicsDirectSpaceState3D = get_root().get_world_3d().direct_space_state
	var oracle: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	var radar_fixture: Dictionary = _find_radial_radar_fixture(high_lod, planet, space_state, oracle)
	_assert(not radar_fixture.is_empty(), "Found a radial high-LOD terrain fixture")
	if not radar_fixture.is_empty():
		var radar_ship_pos: Vector3 = radar_fixture["ship_position"]
		var radar_surface_position: Vector3 = radar_fixture["surface_position"]
		ship.global_position = radar_ship_pos
		var radar_dir: Vector3 = (radar_ship_pos - planet.planet_center_offset).normalized()
		_configure_query(oracle, radar_ship_pos, radar_ship_pos - radar_dir * 5_000.0)
		var hit: Dictionary = space_state.intersect_ray(oracle)
		_assert(not hit.is_empty(), "Physics oracle confirmed the radar fixture surface")
		if not hit.is_empty():
			radar_surface_position = hit["position"]
			var oracle_distance: float = radar_ship_pos.distance_to(radar_surface_position)
			var measured: float = weapon.measure_radar_altitude(space_state, 5_000.0)
			_assert(measured > 0.0 and measured < 5_000.0, "Radar altitude is within range")
			_assert_approx(measured, oracle_distance, 1e-3, "Radar altitude matches the physics oracle")
	_assert(pool.verify_integrity()["is_valid"], "Weapon projectile pool integrity")

	_start_test("Tier 4.4: Weapon zero-allocation firing loop")
	for i in range(100):
		var warm_id: int = weapon.fire_projectile()
		pool.release_projectile(warm_id)
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		var fired_id: int = weapon.fire_projectile()
		pool.release_projectile(fired_id)
	var memory_after: int = OS.get_static_memory_usage()
	_assert(memory_after - memory_before <= 0, "Weapon firing/release has zero static memory growth")
	pool.clear()
	weapon.free()
	ship.free()
	get_root().remove_child(pool)
	pool.free()
	_dispose_planet_fixture(planet, streamer)

func _run_tier_5() -> void:
	print("\n--- Tier 5: Guardrails and Regression Suites ---")
	_start_test("Tier 5.1: Production class names and line limits")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert_int(production_files.size(), 18, "Discovered all 18 production scripts")
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = text.split("\n").size()
		if text.ends_with("\n"):
			line_count -= 1
		_assert(line_count <= 250, "%s has %d lines (limit 250)" % [file, line_count])
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
		if file == "PlanetStreamer.gd":
			_assert(line_count <= 240, "PlanetStreamer.gd has %d lines (limit 240)" % line_count)

	_start_test("Tier 5.2: Steady-state projectile memory")
	var pool: Node = ProjectilePoolManagerClass.new()
	get_root().add_child(pool)
	for i in range(8):
		pool.spawn_projectile(Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0), 1_000_000.0)
	for i in range(200):
		pool.step_projectiles(0.016)
	var before: int = OS.get_static_memory_usage()
	for i in range(2_000):
		pool.step_projectiles(0.016)
	var after: int = OS.get_static_memory_usage()
	_assert(after - before <= 0, "Projectile steady-state loop has no static memory growth")
	pool.clear()
	get_root().remove_child(pool)
	pool.free()

	_start_test("Tier 5.3: Existing Phase 1 and Phase 2 suites")
	var suites: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.begins_with("test_") and file.ends_with(".gd") \
				and file != "test_phase3_streaming_projectiles_headless.gd" \
				and file != "test_phase4_simulation_autopilot_headless.gd":
			suites.append(file)
	suites.sort()
	_assert(suites.size() >= 15, "Discovered all existing headless suites")
	var executable: String = OS.get_executable_path()
	for suite in suites:
		var output: Array = []
		var exit_code: int = OS.execute(
			executable,
			PackedStringArray(["--headless", "-s", ProjectSettings.globalize_path("res://" + suite)]),
			output,
			true
		)
		_assert_int(exit_code, 0, "%s exited successfully" % suite)
		if exit_code != 0:
			printerr("    [SUITE OUTPUT] %s" % str(output))

func _run_hardening() -> void:
	print("\n--- Phase 3 Hardening: Async Convergence and Rebase Alignment ---")
	_start_test("Hardening 1: 30-frame non-blocking async convergence")
	var planet: Node = _make_planet(1)
	var streamer: Node = _make_streamer(planet, false)
	var camera: Vector3 = Vector3(100_050.0, 1_000.0, 1_000.0)
	var completed_in_30: bool = false
	var stable_cancel: int = -1
	for frame in range(30):
		streamer.update_streamer(camera)
		await process_frame
		if streamer.pending_jobs == 0:
			completed_in_30 = true
			stable_cancel = streamer.cancelled_job_count
			break
	_assert(completed_in_30, "Async streaming completed within 30 non-blocking updates")
	for frame in range(10):
		streamer.update_streamer(camera)
		await process_frame
	_assert_int(streamer.cancelled_job_count, stable_cancel, "Stable leaves were not self-cancelled")
	_assert(streamer.queued_job_count > 0, "Async updates queued chunk jobs")
	_assert_int(streamer.pending_jobs, 0, "No jobs remained pending after convergence")
	_assert_int(streamer.get_active_visual_count(), planet.get_all_leaves().size(), "Converged visuals equal active leaves")
	for leaf in planet.get_all_leaves():
		_assert(streamer.mesh_loaded[leaf.mesh_id] != 0, "Converged leaf mesh is loaded")
	_assert_int(streamer.get_orphan_mesh_count(), 0, "Async convergence left zero orphan meshes")
	_assert(planet.audit_system()["is_valid"], "Async convergence preserved quadtree/pool integrity")

	_start_test("Hardening 2: FloatingOrigin visual/collider world alignment")
	var floating_origin: Node = FloatingOrigin.new()
	floating_origin.planet_manager = planet
	get_root().add_child(floating_origin)
	floating_origin.register_entity(streamer)
	var offset: Vector3 = Vector3(2_000.0, 1_000.0, -500.0)
	floating_origin.rebase(offset)
	_assert_vec3(streamer.global_position, planet.planet_center_offset, 1e-4, "Streamer root follows planet center rebase")
	for leaf in planet.get_all_leaves():
		if leaf.collider_id != -1:
			var visual: MeshInstance3D = streamer.visuals[leaf.mesh_id]
			var body: StaticBody3D = planet.collider_pool.get_body(leaf.collider_id)
			_assert_vec3(visual.global_position, body.global_position, 1e-4, "Visual and collider world origins align")
	_dispose_planet_fixture(planet, streamer)
	get_root().remove_child(floating_origin)
	floating_origin.free()
