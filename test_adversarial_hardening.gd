extends SceneTree

## Adversarial Empirical Hardening Test Suite
## 1. Scene-tree hierarchy rebase protection (no double-shifting across registered/unregistered chains)
## 2. Double-rebase guard in SpaceshipController (in-tree/out-of-tree, sleeping, velocity invariance)
## 3. 64-bit sector coordinate tracking across rapid rebases & extreme distances

var total_asserts: int = 0
var passed_asserts: int = 0
var failed_asserts: int = 0
var suite_name: String = ""
var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("==================================================================")
	print("CHALLENGER 2: ADVERSARIAL HARDENING VERIFICATION HARNESS")
	print("==================================================================")
	_test_scene_tree_hierarchy_protection()
	_test_spaceship_double_rebase_guard()
	_test_64bit_sector_tracking_and_extremes()
	print("==================================================================")
	print("HARDENING VERIFICATION SUMMARY: %d/%d assertions passed" % [passed_asserts, total_asserts])
	print("==================================================================")
	if failed_asserts > 0:
		printerr("VERDICT: REQUEST_CHANGES - %d assertions failed!" % failed_asserts)
		quit(1)
	else:
		print("VERDICT: APPROVE - All adversarial hardening tests passed with 0 failures!")
		quit(0)
	return true

func _assert(cond: bool, msg: String) -> void:
	total_asserts += 1
	if not cond:
		failed_asserts += 1
		printerr("  [FAIL] %s: %s" % [suite_name, msg])
	else:
		passed_asserts += 1

func _assert_vec3(act: Vector3, exp: Vector3, tol: float = 1e-4, msg: String = "") -> void:
	total_asserts += 1
	var d: float = (act - exp).length()
	if d > tol:
		failed_asserts += 1
		printerr("  [FAIL] %s: %s (act: %s, exp: %s, diff: %f > tol: %f)" % [suite_name, msg, str(act), str(exp), d, tol])
	else:
		passed_asserts += 1

## Objective 1.1: Scene-Tree Hierarchy Rebase Protection
func _test_scene_tree_hierarchy_protection() -> void:
	suite_name = "HIERARCHY-REBASE"
	print("\n--- Running %s ---" % suite_name)
	var root = get_root()
	var fo: FloatingOrigin = FloatingOrigin.new()
	root.add_child(fo)
	fo.rebase_threshold = 2000.0

	# Case 1: Camera3D direct child of player SpaceshipController (both in tree)
	var ship: SpaceshipController = SpaceshipController.new()
	root.add_child(ship)
	ship.global_position = Vector3(2500.0, 500.0, -100.0)
	var cam: Camera3D = Camera3D.new()
	ship.add_child(cam)
	cam.position = Vector3(0.0, 2.5, 5.0)
	fo.player_node = ship
	fo.register_entity(cam)
	
	_assert(ship.is_inside_tree() and cam.is_inside_tree(), "Nodes not in tree")
	_assert(fo.check_rebase(), "Rebase failed to trigger for player + child camera")
	_assert_vec3(ship.global_position, Vector3.ZERO, 1e-4, "Ship not rebased to origin")
	_assert_vec3(cam.position, Vector3(0.0, 2.5, 5.0), 1e-4, "Camera local transform corrupted")
	_assert_vec3(cam.global_position, Vector3(0.0, 2.5, 5.0), 1e-4, "Camera was double-shifted!")
	
	# Case 2: Deep hierarchy with UNREGISTERED intermediate node: Ship -> Mount (unregistered) -> Sensor (registered)
	var mount: Node3D = Node3D.new()
	var sensor: Node3D = Node3D.new()
	ship.add_child(mount)
	mount.position = Vector3(2.0, 0.0, 0.0)
	mount.add_child(sensor)
	sensor.position = Vector3(0.0, 1.5, 0.0)
	fo.register_entity(sensor) # Register leaf only; mount remains unregistered
	ship.global_position = Vector3(3000.0, 0.0, 0.0)
	fo.check_rebase()
	_assert_vec3(ship.global_position, Vector3.ZERO, 1e-4, "Ship not at origin after unreg mount rebase")
	_assert_vec3(sensor.global_position, Vector3(2.0, 1.5, 0.0), 1e-4, "Sensor double-shifted through unreg parent!")
	
	# Case 3: Parent-child between two registered entities in reversed registration order
	var ent_parent: Node3D = Node3D.new()
	var ent_child: Node3D = Node3D.new()
	root.add_child(ent_parent)
	ent_parent.global_position = Vector3(100.0, 200.0, 300.0)
	ent_parent.add_child(ent_child)
	ent_child.position = Vector3(10.0, 20.0, 30.0)
	fo.register_entity(ent_child) # Child registered first
	fo.register_entity(ent_parent)
	fo.rebase(Vector3(1000.0, 0.0, 0.0))
	_assert_vec3(ent_parent.global_position, Vector3(-900.0, 200.0, 300.0), 1e-4, "Entity parent shifted wrong")
	_assert_vec3(ent_child.global_position, Vector3(-890.0, 220.0, 330.0), 1e-4, "Entity child double-shifted in reverse order")
	_assert_vec3(ent_child.position, Vector3(10.0, 20.0, 30.0), 1e-4, "Entity child local pos altered")

	# Case 4: Child attached to PlanetManager
	var planet: PlanetManager = PlanetManager.new()
	root.add_child(planet)
	fo.planet_manager = planet
	var station: Node3D = Node3D.new()
	planet.add_child(station)
	station.position = Vector3(500.0, 0.0, 0.0)
	fo.register_entity(station)
	fo.rebase(Vector3(500.0, 0.0, 0.0))
	_assert_vec3(station.position, Vector3(500.0, 0.0, 0.0), 1e-4, "Station local pos altered on planet")
	_assert_vec3(station.global_position, planet.global_position + Vector3(500.0, 0.0, 0.0), 1e-4, "Station double-shifted on planet")
	
	fo.queue_free()
	ship.queue_free()
	ent_parent.queue_free()
	planet.destroy()
	planet.queue_free()

## Objective 1.2: Double-Rebase Guard in SpaceshipController
func _test_spaceship_double_rebase_guard() -> void:
	suite_name = "SPACESHIP-DOUBLE-REBASE"
	print("\n--- Running %s ---" % suite_name)
	var root = get_root()
	var ship: SpaceshipController = SpaceshipController.new()
	root.add_child(ship)
	ship.global_position = Vector3(3000.0, -1500.0, 800.0)
	var v_init: Vector3 = Vector3(1200.0, -450.0, 890.0)
	var w_init: Vector3 = Vector3(0.5, -0.25, 1.2)
	ship.linear_velocity = v_init
	ship.angular_velocity = w_init
	
	var offset: Vector3 = Vector3(2000.0, -1000.0, 500.0)
	var exp_pos: Vector3 = ship.global_position - offset
	for i in range(15):
		ship.rebase_origin(offset) # 15 calls in same frame
	_assert_vec3(ship.global_position, exp_pos, 1e-4, "Multiple rebase_origin calls double-shifted!")
	_assert_vec3(ship.linear_velocity, v_init, 1e-5, "Velocity altered across duplicate rebase calls")
	_assert_vec3(ship.angular_velocity, w_init, 1e-5, "Angular velocity altered across duplicate rebase calls")
	
	# Guard resilience when called via FloatingOrigin AND direct caller in same frame
	var fo: FloatingOrigin = FloatingOrigin.new()
	root.add_child(fo)
	fo.player_node = ship
	var pre_direct: Vector3 = ship.global_position
	var offset2: Vector3 = Vector3(100.0, 200.0, 300.0)
	fo.rebase(offset2)          # Call 1 via FloatingOrigin
	ship.rebase_origin(offset2) # Call 2 direct duplicate
	_assert_vec3(ship.global_position, pre_direct - offset2, 1e-4, "Co-invoked FO + direct rebase double-shifted!")
	_assert_vec3(ship.linear_velocity, v_init, 1e-5, "Velocity altered during co-invoked rebase")
	
	# Distinct offset in same frame applies; its duplicate is blocked
	var distinct_offset: Vector3 = Vector3(50.0, 50.0, 50.0)
	ship.rebase_origin(distinct_offset)
	_assert_vec3(ship.global_position, pre_direct - offset2 - distinct_offset, 1e-4, "Distinct offset rebase failed")
	ship.rebase_origin(distinct_offset)
	_assert_vec3(ship.global_position, pre_direct - offset2 - distinct_offset, 1e-4, "Distinct offset duplicate not blocked")

	# Out-of-tree and sleeping state guard test
	var detached_ship: SpaceshipController = SpaceshipController.new()
	detached_ship.position = Vector3(500.0, 500.0, 500.0)
	detached_ship.sleeping = true
	detached_ship.rebase_origin(Vector3(100.0, 0.0, 0.0))
	detached_ship.rebase_origin(Vector3(100.0, 0.0, 0.0)) # duplicate out-of-tree
	_assert_vec3(detached_ship.position, Vector3(400.0, 500.0, 500.0), 1e-4, "Out-of-tree ship double shifted")
	_assert(detached_ship.sleeping, "Sleeping state lost on out-of-tree rebase")
	detached_ship.free()

	fo.queue_free()
	ship.queue_free()

## Objective 1.3: 64-Bit Sector Coordinate Tracking & Numerical Extremes
func _test_64bit_sector_tracking_and_extremes() -> void:
	suite_name = "64BIT-SECTOR-TRACKING"
	print("\n--- Running %s ---" % suite_name)
	var fo: FloatingOrigin = FloatingOrigin.new()
	var planet: PlanetManager = PlanetManager.new()
	
	# Test 1: Negative boundary quadrant crossing
	fo.origin_sector = Vector3i.ZERO
	fo.origin_local = Vector3.ZERO
	fo.rebase(Vector3(-500.0, -2000.0, -2500.0))
	_assert(fo.origin_sector == Vector3i(-1, -1, -2), "Negative sector mismatch: got %s" % str(fo.origin_sector))
	_assert_vec3(fo.origin_local, Vector3(1500.0, 0.0, 1500.0), 1e-4, "Negative remainder mismatch: %s" % str(fo.origin_local))
	var reconstructed: Vector3 = Vector3(fo.origin_sector) * FloatingOrigin.SECTOR_SIZE + fo.origin_local
	_assert_vec3(reconstructed, Vector3(-500.0, -2000.0, -2500.0), 1e-4, "Reconstruction failed for negative coords")
	
	# Test 2: Rapid bidirectional 1,000 rebases
	fo.origin_sector = Vector3i.ZERO
	fo.origin_local = Vector3.ZERO
	fo.accumulated_offset = Vector3.ZERO
	planet.planet_center_sector = Vector3i.ZERO
	planet.planet_center_local = Vector3.ZERO
	planet.planet_center_offset = Vector3.ZERO
	
	for step in range(1000):
		var sx: int = (step % 5) - 2
		var sy: int = ((step * 3) % 7) - 3
		var sz: int = ((step * 7) % 11) - 5
		var step_offset: Vector3 = Vector3(sx * 2000.0 + 125.0, sy * 2000.0 - 50.0, sz * 2000.0 + 300.0)
		fo.rebase(step_offset)
		planet.rebase_origin(step_offset)
		_assert(fo.origin_local.x >= -1e-4 and fo.origin_local.x < FloatingOrigin.SECTOR_SIZE + 1e-4, "FO local.x out of bounds")
		_assert(fo.origin_local.y >= -1e-4 and fo.origin_local.y < FloatingOrigin.SECTOR_SIZE + 1e-4, "FO local.y out of bounds")
		_assert(fo.origin_local.z >= -1e-4 and fo.origin_local.z < FloatingOrigin.SECTOR_SIZE + 1e-4, "FO local.z out of bounds")
	
	var fo_reconstructed: Vector3 = Vector3(fo.origin_sector) * FloatingOrigin.SECTOR_SIZE + fo.origin_local
	_assert_vec3(fo_reconstructed, fo.accumulated_offset, 1e-2, "FO reconstructed offset drifted after 1000 rebases")
	var pl_reconstructed: Vector3 = Vector3(planet.planet_center_sector) * PlanetManager.SECTOR_SIZE + planet.planet_center_local
	_assert_vec3(pl_reconstructed, planet.planet_center_offset, 1e-2, "Planet reconstructed offset drifted after 1000 rebases")
	
	# Test 3: Astronomical distance scaling (10^8 meters to 10^9 meters = 1,000,000 km)
	fo.origin_sector = Vector3i.ZERO
	fo.origin_local = Vector3.ZERO
	var astro_offset: Vector3 = Vector3(100_000_000.0, -200_000_000.0, 500_000_000.0)
	fo.rebase(astro_offset)
	_assert(fo.origin_sector == Vector3i(50000, -100000, 250000), "Astro sector mismatch: %s" % str(fo.origin_sector))
	_assert_vec3(fo.origin_local, Vector3.ZERO, 1e-4, "Astro local remainder non-zero")
	
	# Test 4: Extreme sector integer count (up to 2 billion sectors, Vector3i capacity)
	fo.origin_sector = Vector3i(1_000_000_000, -1_500_000_000, 2_000_000_000)
	fo.origin_local = Vector3(500.0, 1000.0, 1500.0)
	fo.rebase(Vector3(2500.0, -1500.0, 3000.0))
	_assert(fo.origin_sector == Vector3i(1_000_000_001, -1_500_000_001, 2_000_000_002), "Sector overflow / arithmetic error")
	_assert_vec3(fo.origin_local, Vector3(1000.0, 1500.0, 500.0), 1e-4, "Local offset corrupted at 2 billion sectors")
	
	# Test 5: Fractional sub-meter precision
	fo.origin_sector = Vector3i.ZERO
	fo.origin_local = Vector3.ZERO
	fo.rebase(Vector3(0.123456, 0.654321, 0.987654))
	_assert(fo.origin_sector == Vector3i.ZERO, "Sub-meter shift should not increment sector")
	_assert_vec3(fo.origin_local, Vector3(0.123456, 0.654321, 0.987654), 1e-5, "Sub-meter local remainder mismatch")

	fo.free()
	planet.destroy()
	planet.free()
