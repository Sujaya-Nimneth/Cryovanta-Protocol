extends SceneTree

## Adversarial Empirical Stress Test Suite for Cryovanta Protocol
## Focuses on extreme physical, numerical, and boundary conditions:
## 1. Hypersonic velocity extremes (10,000 m/s to 500,000 m/s)
## 2. Sustained continuous multi-frame rebases (1,000 frames)
## 3. Atmospheric boundary continuity & C1 Hermite derivatives
## 4. Zero velocity drag stability & subnormal vectors
## 5. Sustained physics stepping (10,000 steps, 0 byte allocation)

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var test_name: String = ""

func _init() -> void:
	print("==================================================================")
	print("CRYOVANTA PROTOCOL: ADVERSARIAL EMPIRICAL VERIFICATION HARNESS")
	print("==================================================================")
	
	_test_1_high_velocity_extremes()
	_test_2_sustained_continuous_rebases()
	_test_3_atmospheric_ceiling_boundary()
	_test_4_zero_velocity_drag_stability()
	_test_5_sustained_physics_stepping_memory()
	
	print("\n==================================================================")
	print("ADVERSARIAL STRESS TEST SUMMARY: %d/%d assertions passed" % [passed_tests, total_tests])
	print("==================================================================")
	
	if failed_tests > 0:
		printerr("CHALLENGE FAILED: %d failures encountered!" % failed_tests)
		quit(1)
	else:
		print("CHALLENGE PASSED: 100% empirical verification confirmed.")
		quit(0)

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

## 1. High Velocity Extremes (Hypersonic 10,000 m/s to 500,000 m/s)
func _test_1_high_velocity_extremes() -> void:
	test_name = "ADV-1: High Velocity Extremes"
	print("\n--- Running %s ---" % test_name)
	var speeds: Array[float] = [10_000.0, 25_000.0, 50_000.0, 100_000.0, 500_000.0]
	var rho: float = 1.225
	var cd: float = 0.5
	var area: float = 10.0
	
	for s in speeds:
		var vel: Vector3 = Vector3(s, 0.0, 0.0)
		var drag: Vector3 = AtmosphereMath.calculate_drag_force(vel, rho, cd, area)
		var exp_mag: float = 0.5 * rho * cd * area * s * s
		_check_approx(drag.length(), exp_mag, exp_mag * 1e-6, "Drag magnitude mismatch at speed %f" % s)
		_check(drag.x < 0.0 and drag.y == 0.0 and drag.z == 0.0, "Drag direction must oppose motion at speed %f" % s)
		_check(not is_nan(drag.x) and not is_inf(drag.x), "Drag NaN/Inf detected at speed %f" % s)
	
	# Single-frame leap test: vessel leaps 10,000m in 1 frame across 2,000m threshold
	var fo = FloatingOrigin.new()
	var ship = SpaceshipController.new()
	fo.player_node = ship
	fo.rebase_threshold = 2000.0
	ship.position = Vector3(1000.0, 0.0, 0.0)
	ship.linear_velocity = Vector3(10_000.0, -500.0, 250.0)
	ship.angular_velocity = Vector3(0.1, 0.2, 0.3)
	
	# Move position past threshold
	ship.position = Vector3(11_000.0, -500.0, 250.0)
	var rebased: bool = fo.check_rebase()
	_check(rebased, "Failed to trigger rebase on 10,000m single-frame leap")
	_check_approx(ship.position.length(), 0.0, 1e-4, "Ship position not reset to origin on leap")
	_check_approx((ship.linear_velocity - Vector3(10_000.0, -500.0, 250.0)).length(), 0.0, 1e-4, "Linear velocity spike on leap")
	_check_approx((ship.angular_velocity - Vector3(0.1, 0.2, 0.3)).length(), 0.0, 1e-4, "Angular velocity spike on leap")
	fo.free()
	ship.free()

## 2. Sustained Multi-Frame Continuous Rebases (1,000 consecutive frames)
func _test_2_sustained_continuous_rebases() -> void:
	test_name = "ADV-2: Sustained Multi-Frame Continuous Rebases"
	print("\n--- Running %s ---" % test_name)
	var fo = FloatingOrigin.new()
	var ship = SpaceshipController.new()
	var planet = PlanetManager.new()
	var entity = Node3D.new()
	
	fo.player_node = ship
	fo.planet_manager = planet
	fo.register_entity(entity)
	fo.rebase_threshold = 2000.0
	
	planet.planet_radius = 100_000.0
	ship.linear_velocity = Vector3(3000.0, 0.0, 0.0) # > 2000 m/s
	entity.position = Vector3(500.0, 100.0, 20.0)
	
	var rebase_count: int = 0
	var max_v_spike: float = 0.0
	var unshifted_vessel_x: float = 0.0
	var initial_relative_to_entity: Vector3 = entity.position - ship.position
	
	for i in range(1000):
		# Advance vessel position by 2500m along X each frame
		ship.position.x += 2500.0
		unshifted_vessel_x += 2500.0
		
		var v_pre: Vector3 = ship.linear_velocity
		if fo.check_rebase():
			rebase_count += 1
			var v_post: Vector3 = ship.linear_velocity
			max_v_spike = maxf(max_v_spike, (v_post - v_pre).length())
		
		# Invariance check: ship.global_position - planet.planet_center_offset must equal unshifted_vessel_x
		var relative_planet_x: float = ship.position.x - planet.planet_center_offset.x
		if abs(relative_planet_x - unshifted_vessel_x) > 1e-3:
			_check(false, "Relative planet position drift at step %d: %f vs %f" % [i, relative_planet_x, unshifted_vessel_x])
			break
	
	_check(rebase_count == 1000, "Expected 1000 consecutive rebases, got %d" % rebase_count)
	_check_approx(max_v_spike, 0.0, 1e-4, "Max velocity spike across 1000 rebases exceeded tolerance: %f" % max_v_spike)
	# Stationary entity in world: after 1000 rebases of 2500m, its position should be initial - 1000 * 2500m
	var exp_entity_pos: Vector3 = Vector3(500.0 - 2_500_000.0, 100.0, 20.0)
	_check_approx((entity.position - exp_entity_pos).length(), 0.0, 1e-3, "Entity world position mismatch after 1000 rebases")
	_check_approx(planet.planet_center_offset.x, -2_500_000.0, 1e-2, "Planet center offset accumulation mismatch")
	
	fo.free()
	ship.free()
	planet.free()
	entity.free()

## 3. Atmospheric Boundary Continuity & C1 Hermite Derivatives
func _test_3_atmospheric_ceiling_boundary() -> void:
	test_name = "ADV-3: Atmospheric Ceiling Boundary Continuity"
	print("\n--- Running %s ---" % test_name)
	var ceiling: float = 10_000.0
	var surface_rho: float = 1.225
	
	# Strict zero above or at ceiling
	_check(AtmosphereMath.get_air_density(ceiling, ceiling, surface_rho) == 0.0, "Ceiling density must be 0.0")
	_check(AtmosphereMath.get_air_density(ceiling + 1e-6, ceiling, surface_rho) == 0.0, "Ceiling+eps density must be 0.0")
	_check(AtmosphereMath.get_air_density(1e9, ceiling, surface_rho) == 0.0, "Deep space density must be 0.0")
	
	# Smooth C1 Hermite approach from below: derivative d(rho)/dh at ceiling must be 0.0
	var eps: float = 1e-4
	var rho_below: float = AtmosphereMath.get_air_density(ceiling - eps, ceiling, surface_rho)
	_check(rho_below > 0.0, "Density below ceiling must be positive")
	var numerical_deriv: float = (0.0 - rho_below) / eps
	_check_approx(numerical_deriv, 0.0, 1e-3, "Derivative at atmospheric ceiling must be C1 continuous (0.0)")
	
	# Surface boundary & subterranean behavior
	_check(AtmosphereMath.get_air_density(0.0, ceiling, surface_rho) == surface_rho, "Surface density mismatch")
	_check(AtmosphereMath.get_air_density(-500.0, ceiling, surface_rho) == surface_rho, "Subterranean density clamp failed")
	_check(AtmosphereMath.get_air_density(-100_000.0, ceiling, surface_rho) == surface_rho, "Planet center density clamp failed")
	
	# Degenerate ceilings
	_check(AtmosphereMath.get_air_density(500.0, 0.0, surface_rho) == 0.0, "Zero ceiling did not return 0.0")
	_check(AtmosphereMath.get_air_density(500.0, -100.0, surface_rho) == 0.0, "Negative ceiling did not return 0.0")

## 4. Zero Velocity Drag Stability & Subnormal Vectors
func _test_4_zero_velocity_drag_stability() -> void:
	test_name = "ADV-4: Zero Velocity Drag Stability"
	print("\n--- Running %s ---" % test_name)
	var rho: float = 1.225
	
	# Exact zero velocity
	var drag_zero: Vector3 = AtmosphereMath.calculate_drag_force(Vector3.ZERO, rho)
	_check(drag_zero == Vector3.ZERO, "Zero velocity must yield Vector3.ZERO drag")
	_check(not is_nan(drag_zero.x) and not is_inf(drag_zero.x), "Zero velocity drag produced NaN/Inf")
	
	# Subnormal velocities (< 1e-9 threshold)
	var subnormals: Array[Vector3] = [
		Vector3(1e-12, 0.0, 0.0),
		Vector3(0.0, 1e-15, 0.0),
		Vector3(1e-10, -1e-10, 1e-10)
	]
	for sn in subnormals:
		var d: Vector3 = AtmosphereMath.calculate_drag_force(sn, rho)
		_check(d == Vector3.ZERO, "Subnormal velocity must return Vector3.ZERO")
	
	# 8 Directional Octants Opposition Test
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var v: Vector3 = Vector3(sx, sy, sz) * 350.0
				var drag: Vector3 = AtmosphereMath.calculate_drag_force(v, rho)
				var dot_norm: float = drag.normalized().dot(v.normalized())
				_check_approx(dot_norm, -1.0, 1e-4, "Drag did not strictly oppose velocity in octant (%f, %f, %f)" % [sx, sy, sz])
				_check(not is_nan(drag.x) and not is_inf(drag.x), "NaN/Inf in octant drag")

## 5. Sustained Physics Stepping & Memory Growth (10,000 steps)
func _test_5_sustained_physics_stepping_memory() -> void:
	test_name = "ADV-5: Sustained Physics Stepping Memory"
	print("\n--- Running %s ---" % test_name)
	var fo = FloatingOrigin.new()
	var ship = SpaceshipController.new()
	var planet = PlanetManager.new()
	
	fo.player_node = ship
	fo.planet_manager = planet
	ship.planet_manager = planet
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.position = Vector3(0.0, 105_000.0, 0.0) # Altitude 5000m
	ship.set_thrust_input(Vector3(0.5, -0.2, 0.8))
	ship.set_torque_input(Vector3(0.1, 0.2, -0.1))
	ship.linear_velocity = Vector3(250.0, -100.0, 50.0)
	
	# Warmup 100 steps
	for i in range(100):
		ship._physics_process(0.016667)
		fo.check_rebase()
	
	var mem_start: int = OS.get_static_memory_usage()
	for i in range(10_000):
		ship._physics_process(0.016667)
		fo.check_rebase()
		# Periodic rebase trigger every 200 steps
		if i % 200 == 0:
			fo.rebase(Vector3(2001.0, 0.0, 0.0))
	var mem_end: int = OS.get_static_memory_usage()
	var delta: int = mem_end - mem_start
	
	_check(delta == 0, "Memory growth detected across 10,000 steps: %d bytes" % delta)
	fo.free()
	ship.free()
	planet.free()
