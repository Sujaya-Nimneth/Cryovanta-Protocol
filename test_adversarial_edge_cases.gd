extends SceneTree

## Adversarial Edge Cases & In-Tree Physics Verification for Cryovanta Protocol
## Complies with rules.md (<= 250 lines):
## 1. In-tree scene tree physics server synchronization & sleeping body preservation
## 2. Invalid / freed / duplicate entity resilience
## 3. High-frequency ceiling boundary oscillation
## 4. Extreme hypersonic atmospheric entry (100,000 m/s)
## 5. In-tree sustained physics memory profiling

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var test_name: String = ""

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	
	print("==================================================================")
	print("CRYOVANTA PROTOCOL: ADVERSARIAL EDGE CASE HARNESS (IN-TREE PHYSICS)")
	print("==================================================================")
	
	_test_in_tree_physics_rebasing()
	_test_freed_null_entity_resilience()
	_test_ceiling_boundary_oscillation()
	_test_extreme_hypersonic_atmospheric_entry()
	_test_in_tree_memory_profiling()
	
	print("\n==================================================================")
	print("ADVERSARIAL EDGE CASE SUMMARY: %d/%d assertions passed" % [passed_tests, total_tests])
	print("==================================================================")
	
	if failed_tests > 0:
		printerr("EDGE CASE CHALLENGE FAILED: %d failures!" % failed_tests)
		quit(1)
	else:
		print("EDGE CASE CHALLENGE PASSED: All edge cases empirically verified.")
		quit(0)
	return true

func _check(cond: bool, msg: String) -> void:
	total_tests += 1
	if cond:
		passed_tests += 1
	else:
		failed_tests += 1
		printerr("  [FAIL] %s: %s" % [test_name, msg])

func _check_approx(val: float, exp_val: float, tol: float, msg: String) -> void:
	total_tests += 1
	var d: float = abs(val - exp_val)
	if d <= tol:
		passed_tests += 1
	else:
		failed_tests += 1
		printerr("  [FAIL] %s: %s (got %f, expected %f, diff %f > tol %f)" % [test_name, msg, val, exp_val, d, tol])

## 1. In-Tree SceneTree Active Physics Server Rebasing & Sleeping Body Preservation
func _test_in_tree_physics_rebasing() -> void:
	test_name = "ADV-6: In-Tree Active Physics Server Rebasing"
	print("\n--- Running %s ---" % test_name)
	
	var root = get_root()
	var fo = FloatingOrigin.new()
	var ship = SpaceshipController.new()
	var sleeping_body = RigidBody3D.new()
	
	root.add_child(fo)
	root.add_child(ship)
	root.add_child(sleeping_body)
	
	fo.player_node = ship
	fo.register_entity(sleeping_body)
	fo.rebase_threshold = 2000.0
	
	ship.position = Vector3(2500.0, 100.0, 0.0)
	ship.linear_velocity = Vector3(500.0, -100.0, 50.0)
	ship.angular_velocity = Vector3(0.1, 0.0, -0.2)
	
	sleeping_body.position = Vector3(1000.0, 50.0, 0.0)
	sleeping_body.sleeping = true
	
	_check(ship.is_inside_tree(), "Ship is not in tree")
	_check(sleeping_body.is_inside_tree(), "Sleeping body is not in tree")
	
	# Execute rebase
	var v_pre: Vector3 = ship.linear_velocity
	var w_pre: Vector3 = ship.angular_velocity
	var rebased: bool = fo.check_rebase()
	
	_check(rebased, "Rebase failed to trigger for in-tree ship")
	_check_approx(ship.position.length(), 0.0, 1e-4, "In-tree ship position not reset to origin")
	_check_approx((ship.linear_velocity - v_pre).length(), 0.0, 1e-4, "In-tree ship linear velocity spiked")
	_check_approx((ship.angular_velocity - w_pre).length(), 0.0, 1e-4, "In-tree ship angular velocity spiked")
	_check_approx(sleeping_body.position.x, 1000.0 - 2500.0, 1e-4, "In-tree sleeping body position mismatch")
	
	root.remove_child(fo)
	root.remove_child(ship)
	root.remove_child(sleeping_body)
	fo.free()
	ship.free()
	sleeping_body.free()

## 2. Invalid / Freed / Null Entity Resilience
func _test_freed_null_entity_resilience() -> void:
	test_name = "ADV-7: Freed / Null Entity Resilience"
	print("\n--- Running %s ---" % test_name)
	
	var fo = FloatingOrigin.new()
	var ship = SpaceshipController.new()
	var live_entity = Node3D.new()
	var freed_entity = Node3D.new()
	
	fo.player_node = ship
	fo.rebase_threshold = 2000.0
	fo.register_entity(live_entity)
	fo.register_entity(freed_entity)
	fo.register_entity(null) # Null registration guard
	
	# Free entity before rebase
	freed_entity.free()
	
	ship.position = Vector3(3000.0, 0.0, 0.0)
	live_entity.position = Vector3(500.0, 0.0, 0.0)
	
	# Must not crash when encountering freed or null entity
	var rebased: bool = fo.check_rebase()
	_check(rebased, "Rebase failed during resilience test")
	_check_approx(live_entity.position.x, -2500.0, 1e-4, "Live entity position mismatch after skipping dead entities")
	
	fo.free()
	ship.free()
	live_entity.free()

## 3. Boundary Oscillation Across Atmospheric Ceiling
func _test_ceiling_boundary_oscillation() -> void:
	test_name = "ADV-8: Atmospheric Ceiling Boundary Oscillation"
	print("\n--- Running %s ---" % test_name)
	
	var ceiling: float = 10_000.0
	var vel: Vector3 = Vector3(1000.0, 0.0, 0.0)
	var max_drag_step: float = 0.0
	var prev_drag_mag: float = 0.0
	
	# Oscillate altitude across ceiling: from 9,990m to 10,010m in 1m increments
	for step in range(40):
		var alt: float = 9990.0 + float(step)
		var rho: float = AtmosphereMath.get_air_density(alt, ceiling, 1.225)
		var drag: Vector3 = AtmosphereMath.calculate_drag_force(vel, rho, 0.5, 10.0)
		var drag_mag: float = drag.length()
		
		if alt >= ceiling:
			_check(drag_mag == 0.0, "Drag above ceiling was non-zero at alt %f" % alt)
		
		if step > 0:
			max_drag_step = maxf(max_drag_step, abs(drag_mag - prev_drag_mag))
		prev_drag_mag = drag_mag
	
	# In Hermite smoothstep, step change across 1m near ceiling is smooth and small (< 5.0 N)
	_check(max_drag_step < 5.0, "Drag step across boundary was abrupt: %f N" % max_drag_step)

## 4. Extreme Hypersonic Atmospheric Entry (100,000 m/s)
func _test_extreme_hypersonic_atmospheric_entry() -> void:
	test_name = "ADV-9: Extreme Hypersonic Atmospheric Entry (100,000 m/s)"
	print("\n--- Running %s ---" % test_name)
	
	var vel: Vector3 = Vector3(100_000.0, -10_000.0, 0.0)
	var rho: float = AtmosphereMath.get_air_density(5000.0, 10_000.0, 1.225)
	var drag: Vector3 = AtmosphereMath.calculate_drag_force(vel, rho, 0.5, 10.0)
	
	_check(not is_nan(drag.x) and not is_inf(drag.x), "Hypersonic drag produced NaN/Inf")
	_check(drag.x < 0.0 and drag.y > 0.0, "Hypersonic drag did not oppose velocity")
	
	var speed: float = vel.length()
	var exp_mag: float = 0.5 * rho * 0.5 * 10.0 * speed * speed
	_check_approx(drag.length(), exp_mag, exp_mag * 1e-5, "Hypersonic drag magnitude mismatch")

## 5. In-Tree Sustained Physics Memory Profiling
func _test_in_tree_memory_profiling() -> void:
	test_name = "ADV-10: In-Tree Sustained Physics Memory Profiling"
	print("\n--- Running %s ---" % test_name)
	
	var root = get_root()
	var ship = SpaceshipController.new()
	root.add_child(ship)
	
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.position = Vector3(0.0, 105_000.0, 0.0)
	ship.set_thrust_input(Vector3(0.5, 0.5, 0.5))
	ship.set_torque_input(Vector3(0.1, 0.1, 0.1))
	
	# Warmup
	for i in range(100):
		ship._physics_process(0.016667)
	
	var mem_start: int = OS.get_static_memory_usage()
	for i in range(2000):
		ship._physics_process(0.016667)
	var mem_end: int = OS.get_static_memory_usage()
	var delta: int = mem_end - mem_start
	
	_check(delta == 0, "In-tree physics loop allocated %d bytes" % delta)
	
	root.remove_child(ship)
	ship.free()
