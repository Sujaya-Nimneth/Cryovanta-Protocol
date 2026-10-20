extends SceneTree

## Adversarial Empirical Verification Suite - Challenger 2
## Targets:
## 1. Quadtree chunks visual & topological continuity across rebases (PlanetManager)
## 2. 6-DOF dynamics & velocity spike (< 1e-4) under active thrust + dynamic drag across rebase frame
## 3. Multi-body and sleeping body phantom impulses upon coordinate shift

var total_asserts: int = 0
var passed_asserts: int = 0
var failed_asserts: int = 0
var current_test_name: String = ""

var FloatingOriginClass = null
var SpaceshipControllerClass = null
var AtmosphereMathClass = null
var PlanetManagerClass = null

func _init() -> void:
	print("==================================================================")
	print("CHALLENGER 2: ADVERSARIAL EMPIRICAL VERIFICATION HARNESS")
	print("==================================================================")
	
	FloatingOriginClass = load("res://FloatingOrigin.gd")
	SpaceshipControllerClass = load("res://SpaceshipController.gd")
	AtmosphereMathClass = load("res://AtmosphereMath.gd")
	PlanetManagerClass = load("res://PlanetManager.gd")
	
	_run_adversarial_suite()

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

## Helper to let Quadtree LOD reach steady-state convergence
func _converge_planet(planet: PlanetManager, cam_pos: Vector3, max_steps: int = 12) -> void:
	var prev_leaves: int = -1
	for step in range(max_steps):
		planet.update_camera(cam_pos)
		var current_leaves: int = planet.audit_system()["leaf_nodes"]
		if current_leaves == prev_leaves:
			break
		prev_leaves = current_leaves

func _run_adversarial_suite() -> void:
	# -------------------------------------------------------------
	# SECTION 1: Quadtree Continuity Across Rebases
	# -------------------------------------------------------------
	_test_quadtree_continuity_single_rebase()
	_test_quadtree_continuity_all_faces_deep_lod()
	_test_quadtree_continuity_hysteresis_boundaries()
	_test_quadtree_sequential_rapid_rebases()
	_test_quadtree_extreme_rebase_offsets()
	
	# -------------------------------------------------------------
	# SECTION 2: 6-DOF Dynamics & Velocity Spike Across Rebase
	# -------------------------------------------------------------
	_test_6dof_instantaneous_velocity_spike()
	_test_6dof_continuous_flight_rebases()
	_test_6dof_compound_multi_ship_rebase()
	
	# -------------------------------------------------------------
	# SECTION 3: Multi-Body & Sleeping Bodies Phantom Impulses
	# -------------------------------------------------------------
	_test_sleeping_body_state_and_impulse()
	_test_sleeping_body_on_static_surface_rebase()
	_test_heterogeneous_relative_distance_invariance()
	
	# -------------------------------------------------------------
	# SUMMARY
	# -------------------------------------------------------------
	print("==================================================================")
	print("CHALLENGER 2 VERIFICATION SUMMARY")
	print("  Total Assertions:  %d" % total_asserts)
	print("  Passed Assertions: %d" % passed_asserts)
	print("  Failed Assertions: %d" % failed_asserts)
	print("==================================================================")
	
	if failed_asserts > 0:
		printerr("VERDICT: REQUEST_CHANGES - %d assertion failures!" % failed_asserts)
		quit(1)
	else:
		print("VERDICT: APPROVE - All adversarial tests passed with 0 failures!")
		quit(0)

# ==============================================================================
# SECTION 1 IMPLEMENTATION: Quadtree Continuity Across Rebases
# ==============================================================================

func _test_quadtree_continuity_single_rebase() -> void:
	_start_test("QUADTREE 1.1: Single Rebase Topology & Mesh Invariance")
	var planet: PlanetManager = PlanetManagerClass.new()
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var cam: Node3D = Node3D.new()
	
	fo.planet_manager = planet
	fo.player_node = cam
	
	# Position camera near surface of face 0 (+X) to generate deep LOD
	cam.position = Vector3(planet.planet_radius + 500.0, 100.0, 50.0)
	_converge_planet(planet, cam.position)
	
	# Audit tree before rebase
	var audit_before: Dictionary = planet.audit_system()
	_assert(audit_before["is_valid"], "Tree invalid before rebase")
	_assert(audit_before["orphan_count"] == 0, "Orphans present before rebase")
	
	var leaves_before: Array[QuadtreeNode] = planet.get_all_leaves()
	var leaf_count_before: int = leaves_before.size()
	var leaf_signatures_before: Dictionary = {}
	for leaf in leaves_before:
		# Signature: face, lod, uv_min, uv_max, mesh_id
		var sig: String = "%d_%d_%s_%s" % [leaf.face_index, leaf.lod_level, str(leaf.uv_min), str(leaf.uv_max)]
		leaf_signatures_before[sig] = leaf.mesh_id
	
	# Trigger rebase by crossing threshold
	var offset: Vector3 = cam.position
	fo.rebase(offset)
	
	# Evaluate LOD again with camera at new position
	planet.update_camera(cam.position)
	
	var audit_after: Dictionary = planet.audit_system()
	_assert(audit_after["is_valid"], "Tree invalid after rebase")
	_assert(audit_after["orphan_count"] == 0, "Orphan nodes detected after rebase!")
	_assert(audit_after["leaf_nodes"] == leaf_count_before, 
		"Leaf count changed across rebase! Before: %d, After: %d" % [leaf_count_before, audit_after["leaf_nodes"]])
	_assert(audit_after["active_meshes"] == audit_before["active_meshes"],
		"Active mesh count changed across rebase!")
	
	# Verify every single leaf chunk signature and mesh ID is strictly preserved
	var leaves_after: Array[QuadtreeNode] = planet.get_all_leaves()
	for leaf in leaves_after:
		var sig: String = "%d_%d_%s_%s" % [leaf.face_index, leaf.lod_level, str(leaf.uv_min), str(leaf.uv_max)]
		_assert(leaf_signatures_before.has(sig), "Unexpected chunk created after rebase: %s" % sig)
		if leaf_signatures_before.has(sig):
			_assert(leaf.mesh_id == leaf_signatures_before[sig], 
				"Mesh ID changed across rebase for chunk %s! Before: %d, After: %d" % [
					sig, leaf_signatures_before[sig], leaf.mesh_id
				])
	
	cam.free()
	fo.free()
	planet.destroy()
	planet.free()

func _test_quadtree_continuity_all_faces_deep_lod() -> void:
	_start_test("QUADTREE 1.2: Continuity Across All 6 Cube Faces Under Deep LOD")
	var planet: PlanetManager = PlanetManagerClass.new()
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var cam: Node3D = Node3D.new()
	fo.planet_manager = planet
	fo.player_node = cam
	
	var face_dirs: Array[Vector3] = [
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1)
	]
	
	for face_idx in range(6):
		var dir: Vector3 = face_dirs[face_idx]
		# Move close to face center
		var world_cam: Vector3 = dir * (planet.planet_radius + 200.0) + planet.planet_center_offset
		cam.position = world_cam
		_converge_planet(planet, cam.position)
		
		var audit_pre: Dictionary = planet.audit_system()
		var pre_leaves: int = audit_pre["leaf_nodes"]
		_assert(audit_pre["is_valid"] and audit_pre["orphan_count"] == 0, 
			"Face %d pre-rebase audit failed" % face_idx)
		
		# Rebase
		fo.rebase(cam.position)
		planet.update_camera(cam.position)
		
		var audit_post: Dictionary = planet.audit_system()
		_assert(audit_post["orphan_count"] == 0, 
			"Face %d orphan nodes detected post-rebase: %d" % [face_idx, audit_post["orphan_count"]])
		_assert(audit_post["leaf_nodes"] == pre_leaves,
			"Face %d leaf nodes split/merged unexpectedly: pre %d vs post %d" % [
				face_idx, pre_leaves, audit_post["leaf_nodes"]
			])
		_assert(audit_post["active_meshes"] == audit_pre["active_meshes"],
			"Face %d active meshes mismatch post-rebase" % face_idx)
	
	cam.free()
	fo.free()
	planet.destroy()
	planet.free()

func _test_quadtree_continuity_hysteresis_boundaries() -> void:
	_start_test("QUADTREE 1.3: Hysteresis Boundary Stress Testing")
	var planet: PlanetManager = PlanetManagerClass.new()
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var cam: Node3D = Node3D.new()
	fo.planet_manager = planet
	fo.player_node = cam
	
	# Find a root node bounding radius
	var root: QuadtreeNode = planet.face_roots[0]
	var split_dist: float = root.bounding_radius * planet.split_ratio
	var merge_dist: float = split_dist * planet.hysteresis
	
	# Test exact split distance boundary
	var test_distances: Array[float] = [
		split_dist - 0.001,
		split_dist,
		split_dist + 0.001,
		merge_dist - 0.001,
		merge_dist,
		merge_dist + 0.001
	]
	
	for d in test_distances:
		cam.position = Vector3(d, 0.0, 0.0) + planet.planet_center_offset
		_converge_planet(planet, cam.position)
		var leaves_before: int = planet.audit_system()["leaf_nodes"]
		
		fo.rebase(cam.position)
		planet.update_camera(cam.position)
		var leaves_after: int = planet.audit_system()["leaf_nodes"]
		var audit: Dictionary = planet.audit_system()
		
		_assert(audit["orphan_count"] == 0, "Orphan at boundary distance %f" % d)
		_assert(leaves_before == leaves_after, 
			"Boundary distance %f caused unexpected split/merge on rebase: %d -> %d" % [d, leaves_before, leaves_after])
	
	cam.free()
	fo.free()
	planet.destroy()
	planet.free()

func _test_quadtree_sequential_rapid_rebases() -> void:
	_start_test("QUADTREE 1.4: 100 Sequential High-Frequency Rapid Rebases")
	var planet: PlanetManager = PlanetManagerClass.new()
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var cam: Node3D = Node3D.new()
	fo.planet_manager = planet
	fo.player_node = cam
	
	# High-speed circular orbit simulation triggering continuous rebases
	var angle: float = 0.0
	var radius: float = planet.planet_radius + 3000.0
	var total_rebases: int = 0
	
	for step in range(200):
		angle += 0.05
		# Move camera
		var pos_target: Vector3 = Vector3(cos(angle), sin(angle), sin(angle * 0.5)).normalized() * radius
		cam.position = pos_target + planet.planet_center_offset
		
		if fo.check_rebase():
			total_rebases += 1
		
		planet.update_camera(cam.position)
		
		var audit: Dictionary = planet.audit_system()
		if audit["orphan_count"] != 0 or not audit["is_valid"]:
			_fail("Rapid rebase step %d failed! Orphans: %d, Errors: %s" % [
				step, audit["orphan_count"], str(audit["errors"])
			])
			break
	
	var final_audit: Dictionary = planet.audit_system()
	_assert(final_audit["orphan_count"] == 0, "Final orphan count > 0 after rapid rebases")
	_assert(final_audit["is_valid"], "Final audit invalid after rapid rebases")
	_assert(total_rebases > 50, "Expected > 50 rebases during high-speed orbit, got %d" % total_rebases)
	
	cam.free()
	fo.free()
	planet.destroy()
	planet.free()

func _test_quadtree_extreme_rebase_offsets() -> void:
	_start_test("QUADTREE 1.5: Extreme Rebase Offsets (Astronomical Coordinates)")
	var planet: PlanetManager = PlanetManagerClass.new()
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var cam: Node3D = Node3D.new()
	fo.planet_manager = planet
	fo.player_node = cam
	
	# Extreme shifts up to 10^9 meters
	var extreme_offsets: Array[Vector3] = [
		Vector3(1e6, -2e6, 3e6),
		Vector3(-5e7, 1e8, -2e8),
		Vector3(1e9, 1e9, 1e9)
	]
	
	for off in extreme_offsets:
		cam.position = Vector3(planet.planet_radius + 1000.0, 0, 0) + planet.planet_center_offset
		_converge_planet(planet, cam.position)
		var leaves_before: int = planet.audit_system()["leaf_nodes"]
		
		# Rebase by offset
		fo.rebase(off)
		planet.update_camera(cam.position)
		
		var audit: Dictionary = planet.audit_system()
		_assert(audit["orphan_count"] == 0, "Orphans after extreme offset %s" % str(off))
		_assert(audit["leaf_nodes"] == leaves_before, 
			"Leaf node change after extreme offset %s: %d -> %d" % [str(off), leaves_before, audit["leaf_nodes"]])
	
	cam.free()
	fo.free()
	planet.destroy()
	planet.free()

# ==============================================================================
# SECTION 2 IMPLEMENTATION: 6-DOF Dynamics & Velocity Spike Across Rebase
# ==============================================================================

func _test_6dof_instantaneous_velocity_spike() -> void:
	_start_test("6-DOF 2.1: Instantaneous Velocity Spike (< 1e-4) Across Rebase Under Full Spectrum Inputs")
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var ship: SpaceshipController = SpaceshipControllerClass.new()
	ship.mass = 5000.0
	fo.player_node = ship
	
	# Test battery across thrust, torque, velocity, and altitude regimes
	var test_cases: Array[Dictionary] = [
		{"thrust": Vector3(1.0, 0.0, 0.0), "torque": Vector3.ZERO, "vel": Vector3(500, 0, 0), "alt": 1000.0},
		{"thrust": Vector3(0.0, 1.0, 0.0), "torque": Vector3.ZERO, "vel": Vector3(0, -300, 0), "alt": 5000.0},
		{"thrust": Vector3(0.0, 0.0, 1.0), "torque": Vector3.ZERO, "vel": Vector3(0, 0, 2000), "alt": 500.0},
		{"thrust": Vector3(1.0, 1.0, 1.0), "torque": Vector3(1.0, 1.0, 1.0), "vel": Vector3(1000, 500, -800), "alt": 200.0},
		{"thrust": Vector3(-1.0, -1.0, -1.0), "torque": Vector3(-1.0, -1.0, -1.0), "vel": Vector3(-1000, -500, 800), "alt": 9500.0},
		# Hypersonic speed in atmosphere
		{"thrust": Vector3(0.0, 0.0, 1.0), "torque": Vector3.ZERO, "vel": Vector3(8000, 0, 0), "alt": 1000.0},
		# Vacuum boundary
		{"thrust": Vector3(0.5, 0.5, 0.5), "torque": Vector3(0.5, 0.5, 0.5), "vel": Vector3(7000, -1000, 500), "alt": 15000.0}
	]
	
	var max_spike: float = 0.0
	for tc in test_cases:
		ship.position = Vector3(2500.0, tc["alt"] + ship.planet_radius, 0.0)
		ship.linear_velocity = tc["vel"]
		ship.angular_velocity = tc["torque"] * 2.0
		ship.set_thrust_input(tc["thrust"])
		ship.set_torque_input(tc["torque"])
		
		# Execute physics step to compute drag and thrust
		ship._physics_process(0.016667)
		
		var v_pre: Vector3 = ship.linear_velocity
		var w_pre: Vector3 = ship.angular_velocity
		
		# Trigger rebase
		var rebased: bool = fo.check_rebase()
		_assert(rebased, "Rebase did not trigger for position %s" % str(ship.position))
		
		var v_post: Vector3 = ship.linear_velocity
		var w_post: Vector3 = ship.angular_velocity
		
		var v_diff: float = (v_post - v_pre).length()
		var w_diff: float = (w_post - w_pre).length()
		max_spike = maxf(max_spike, maxf(v_diff, w_diff))
		
		_assert_approx(v_diff, 0.0, 1e-4, "Linear velocity spike exceeded 1e-4: %f" % v_diff)
		_assert_approx(w_diff, 0.0, 1e-4, "Angular velocity spike exceeded 1e-4: %f" % w_diff)
	
	print("  Max instantaneous velocity spike across all cases: %.8f" % max_spike)
	ship.free()
	fo.free()

func _test_6dof_continuous_flight_rebases() -> void:
	_start_test("6-DOF 2.2: 500 Continuous Flight Physics Steps with Multi-Rebases")
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var ship: SpaceshipController = SpaceshipControllerClass.new()
	var planet: PlanetManager = PlanetManagerClass.new()
	
	fo.player_node = ship
	fo.planet_manager = planet
	ship.planet_manager = planet
	ship.mass = 5000.0
	
	# High-speed flight: 2500 m/s covers 20,833m in 500 steps (8.33s), triggering > 10 rebases
	ship.position = Vector3(1000.0, planet.planet_radius + 5000.0, 0.0)
	ship.linear_velocity = Vector3(2500.0, -50.0, 100.0)
	ship.set_thrust_input(Vector3(0.2, 0.0, 0.8))
	ship.set_torque_input(Vector3(0.05, 0.02, 0.0))
	
	var rebase_count: int = 0
	var max_spike: float = 0.0
	var dt: float = 0.016667
	
	for step in range(500):
		var v_pre: Vector3 = ship.linear_velocity
		var w_pre: Vector3 = ship.angular_velocity
		
		if fo.check_rebase():
			rebase_count += 1
			var v_post: Vector3 = ship.linear_velocity
			var w_post: Vector3 = ship.angular_velocity
			var v_spike: float = (v_post - v_pre).length()
			var w_spike: float = (w_post - w_pre).length()
			max_spike = maxf(max_spike, maxf(v_spike, w_spike))
		
		ship._physics_process(dt)
		ship.position += ship.linear_velocity * dt
		
		_assert(not is_nan(ship.linear_velocity.x), "Velocity became NaN at step %d" % step)
		_assert(not is_inf(ship.linear_velocity.x), "Velocity became Inf at step %d" % step)
	
	_assert(rebase_count >= 10, "Expected >= 10 rebases over 500 flight steps, got %d" % rebase_count)
	_assert_approx(max_spike, 0.0, 1e-4, "Max velocity spike across flight rebases: %.8f" % max_spike)
	
	ship.free()
	fo.free()
	planet.destroy()
	planet.free()

func _test_6dof_compound_multi_ship_rebase() -> void:
	_start_test("6-DOF 2.3: Multi-Ship Formation Rebase Velocity Invariance")
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var lead_ship: SpaceshipController = SpaceshipControllerClass.new()
	lead_ship.mass = 5000.0
	fo.player_node = lead_ship
	
	var wingmen: Array[SpaceshipController] = []
	for i in range(5):
		var w: SpaceshipController = SpaceshipControllerClass.new()
		w.mass = 4000.0 + i * 500.0
		w.position = Vector3(2000.0 + i * 50.0, 500.0, i * 20.0)
		w.linear_velocity = Vector3(300.0, 50.0 * i, -20.0 * i)
		w.angular_velocity = Vector3(0.01 * i, 0.02 * i, 0.0)
		w.set_thrust_input(Vector3(0.2 * i, 0.0, 0.8))
		fo.register_entity(w)
		wingmen.append(w)
	
	lead_ship.position = Vector3(2200.0, 500.0, 0.0)
	lead_ship.linear_velocity = Vector3(300.0, 0.0, 0.0)
	
	var pre_vels: Array[Vector3] = []
	for w in wingmen:
		pre_vels.append(w.linear_velocity)
	
	fo.check_rebase()
	
	for i in range(5):
		var post_vel: Vector3 = wingmen[i].linear_velocity
		var diff: float = (post_vel - pre_vels[i]).length()
		_assert_approx(diff, 0.0, 1e-4, "Wingman %d velocity altered by rebase: diff %f" % [i, diff])
		wingmen[i].free()
	
	lead_ship.free()
	fo.free()

# ==============================================================================
# SECTION 3 IMPLEMENTATION: Multi-Body & Sleeping Bodies Phantom Impulses
# ==============================================================================

func _test_sleeping_body_state_and_impulse() -> void:
	_start_test("MULTI-BODY 3.1: Sleeping Body State & Phantom Impulse Verification")
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var player: Node3D = Node3D.new()
	fo.player_node = player
	
	var sleepers: Array[RigidBody3D] = []
	for i in range(5):
		var s: RigidBody3D = RigidBody3D.new()
		s.position = Vector3(2100.0 + i * 200.0, i * 50.0, -i * 100.0)
		s.linear_velocity = Vector3.ZERO
		s.angular_velocity = Vector3.ZERO
		s.sleeping = true
		fo.register_entity(s)
		sleepers.append(s)
	
	player.position = Vector3(2200.0, 0.0, 0.0)
	var rebased: bool = fo.check_rebase()
	_assert(rebased, "Rebase failed to trigger")
	
	for i in range(5):
		var s: RigidBody3D = sleepers[i]
		_assert_vec3_approx(s.linear_velocity, Vector3.ZERO, 1e-9, 
			"Phantom linear impulse injected on sleeper %d: %s" % [i, str(s.linear_velocity)])
		_assert_vec3_approx(s.angular_velocity, Vector3.ZERO, 1e-9,
			"Phantom angular impulse injected on sleeper %d: %s" % [i, str(s.angular_velocity)])
		_assert(s.sleeping == true, "Sleeper %d sleeping flag not preserved!" % i)
		s.free()
	
	player.free()
	fo.free()

func _test_sleeping_body_on_static_surface_rebase() -> void:
	_start_test("MULTI-BODY 3.2: Sleeping Body Resting on Static Surface Shift")
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var player: Node3D = Node3D.new()
	fo.player_node = player
	
	# Static platform
	var platform: StaticBody3D = StaticBody3D.new()
	platform.position = Vector3(3000.0, 0.0, 0.0)
	fo.register_entity(platform)
	
	# Sleeping box resting on platform
	var cargo: RigidBody3D = RigidBody3D.new()
	cargo.position = Vector3(3000.0, 1.0, 0.0)
	cargo.linear_velocity = Vector3.ZERO
	cargo.angular_velocity = Vector3.ZERO
	cargo.sleeping = true
	fo.register_entity(cargo)
	
	# Trigger rebase
	player.position = Vector3(2500.0, 0.0, 0.0)
	fo.check_rebase()
	
	# Verify relative distance between cargo and platform is exactly 1.0 along Y and 0 along X, Z
	var rel_pos: Vector3 = cargo.position - platform.position
	_assert_vec3_approx(rel_pos, Vector3(0.0, 1.0, 0.0), 1e-4, 
		"Relative offset between resting cargo and static surface corrupted across rebase: %s" % str(rel_pos))
	_assert_vec3_approx(cargo.linear_velocity, Vector3.ZERO, 1e-9,
		"Cargo gained linear velocity on static platform: %s" % str(cargo.linear_velocity))
	_assert_vec3_approx(cargo.angular_velocity, Vector3.ZERO, 1e-9,
		"Cargo gained angular velocity on static platform: %s" % str(cargo.angular_velocity))
	_assert(cargo.sleeping == true, "Cargo woke up on platform after rebase")
	
	player.free()
	platform.free()
	cargo.free()
	fo.free()

func _test_heterogeneous_relative_distance_invariance() -> void:
	_start_test("MULTI-BODY 3.3: Heterogeneous Entity Relative Invariance Across Rebase")
	var fo: FloatingOrigin = FloatingOriginClass.new()
	var player: Node3D = Node3D.new()
	fo.player_node = player
	
	var entities: Array[Node3D] = []
	for i in range(10):
		var n: Node3D = Node3D.new()
		n.position = Vector3(randf_range(1000, 5000), randf_range(-1000, 1000), randf_range(-2000, 2000))
		fo.register_entity(n)
		entities.append(n)
	
	# Compute pair-wise distances before rebase
	var distances_before: Array[float] = []
	for i in range(entities.size() - 1):
		distances_before.append(entities[i].position.distance_to(entities[i + 1].position))
	
	# Perform rebase
	player.position = Vector3(3500.0, 500.0, -1200.0)
	fo.check_rebase()
	
	# Verify pair-wise distances after rebase (5e-4 accounts for 1-2 ULP 32-bit float rounding at 3000m coordinates)
	for i in range(entities.size() - 1):
		var dist_after: float = entities[i].position.distance_to(entities[i + 1].position)
		_assert_approx(dist_after, distances_before[i], 5e-4, 
			"Pair-wise distance between entity %d and %d changed across rebase!" % [i, i + 1])
	
	player.free()
	for e in entities:
		e.free()
	fo.free()
