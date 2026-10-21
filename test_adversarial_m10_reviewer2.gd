extends SceneTree

## Adversarial Verification & Stress Harness for Milestone M10 (Reviewer 2)
## Tests:
## 1. Zero Runtime Heap Allocations (50,000 math calls & 10,000 physics steps)
## 2. Floating Origin 2,000m Rebase Invariance (Standalone & In-Tree PhysicsServer3D)
## 3. Mathematical Exactness, C0 Continuity, and Singularity Hardening
## 4. Orbital Freefall Dynamics & Energy Conservation Across Rebases
## 5. Backward Compatibility (Flag default false, 0 perturbation)
## 6. Anti-Facade Dynamic Integrity Audit (Randomized parameter validation)

const AtmosphereMath = preload("res://AtmosphereMath.gd")
const SpaceshipController = preload("res://SpaceshipController.gd")
const FloatingOrigin = preload("res://FloatingOrigin.gd")
const PlanetManager = preload("res://PlanetManager.gd")

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

func _assert_near(val: float, target: float, tol: float, msg: String) -> void:
	var diff: float = absf(val - target)
	_assert(diff <= tol, "%s (got %f, expected %f, diff %f > tol %f)" % [msg, val, target, diff, tol])

func _assert_vec3_near(val: Vector3, target: Vector3, tol: float, msg: String) -> void:
	var diff: float = (val - target).length()
	_assert(diff <= tol, "%s (got %s, expected %s, diff %f > tol %f)" % [msg, str(val), str(target), diff, tol])

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	
	print("==================================================================")
	print("REVIEWER 2: ADVERSARIAL STRESS & VERIFICATION HARNESS (M10)")
	print("==================================================================")
	
	test_adv1_zero_allocation_sustained()
	test_adv2_floating_origin_rebase_invariance()
	test_adv3_mathematical_continuity_and_singularities()
	test_adv4_orbital_freefall_energy_conservation()
	test_adv5_backward_compatibility()
	test_adv6_dynamic_integrity_audit()
	
	print("==================================================================")
	print("REVIEWER 2 SUMMARY: %d/%d assertions passed" % [passed_assertions, total_assertions])
	if failed_assertions == 0:
		print("VERDICT: APPROVE - All adversarial, memory, and physics tests passed!")
		quit(0)
	else:
		printerr("VERDICT: REQUEST_CHANGES - %d assertions failed!" % failed_assertions)
		quit(1)
	return true

## -----------------------------------------------------------------------------
## ADV 1: Zero Runtime Heap Allocations (Sustained Memory Profiling)
## -----------------------------------------------------------------------------
func test_adv1_zero_allocation_sustained() -> void:
	print("\n--- ADV 1: Sustained Zero Heap Allocations ---")
	
	# Part A: Pure Static Math (50,000 calls)
	var v_pos: Vector3 = Vector3(150_000.0, 20_000.0, -80_000.0)
	var p_pos: Vector3 = Vector3(10_000.0, -5_000.0, 2_000.0)
	var p_rad: float = 100_000.0
	
	# Warm-up
	for i in range(100):
		var _dummy = AtmosphereMath.calculate_gravity_acceleration(v_pos, p_pos, p_rad, 9.81)
	
	var mem_math_before: int = OS.get_static_memory_usage()
	for i in range(50000):
		var _res: Vector3 = AtmosphereMath.calculate_gravity_acceleration(v_pos, p_pos, p_rad, 9.81)
	var mem_math_after: int = OS.get_static_memory_usage()
	_assert(mem_math_after == mem_math_before, "AtmosphereMath.calculate_gravity_acceleration 0 bytes over 50,000 calls (delta = %d)" % (mem_math_after - mem_math_before))
	
	# Part B: SpaceshipController with active gravity and PlanetManager (10,000 steps)
	var ship: SpaceshipController = SpaceshipController.new()
	var pm: PlanetManager = PlanetManager.new()
	pm.planet_radius = 80_000.0
	pm.planet_center_offset = Vector3(0.0, -80_000.0, 0.0)
	
	ship.planet_manager = pm
	ship.enable_planetary_gravity = true
	ship.surface_gravity = 9.81
	ship.mass = 2500.0
	ship.position = Vector3(100.0, 5000.0, -200.0)
	ship.linear_velocity = Vector3(120.0, -45.0, 80.0)
	ship.thrust_input = Vector3(0.5, -0.2, 1.0)
	ship.torque_input = Vector3(0.1, -0.3, 0.2)
	
	# Warm-up
	for i in range(200):
		ship._physics_process(0.016667)
	
	var mem_ship_before: int = OS.get_static_memory_usage()
	for i in range(10000):
		ship._physics_process(0.016667)
	var mem_ship_after: int = OS.get_static_memory_usage()
	_assert(mem_ship_after == mem_ship_before, "SpaceshipController._physics_process 0 bytes over 10,000 steps with gravity + inputs + PlanetManager (delta = %d)" % (mem_ship_after - mem_ship_before))
	
	ship.free()
	pm.free()

## -----------------------------------------------------------------------------
## ADV 2: Floating Origin 2,000m Rebase Invariance
## -----------------------------------------------------------------------------
func test_adv2_floating_origin_rebase_invariance() -> void:
	print("\n--- ADV 2: Floating Origin Rebase Invariance ---")
	var root: Window = get_root()
	var fo: FloatingOrigin = FloatingOrigin.new()
	var ship: SpaceshipController = SpaceshipController.new()
	var pm: PlanetManager = PlanetManager.new()
	
	pm.planet_radius = 60_000.0
	pm.planet_center_offset = Vector3(0.0, -60_000.0, 0.0)
	
	ship.planet_manager = pm
	ship.enable_planetary_gravity = true
	ship.surface_gravity = 9.81
	ship.mass = 1800.0
	
	fo.player_node = ship
	fo.planet_manager = pm
	root.add_child(ship)
	
	# Test various rebase directions and high speeds (10,000 m/s)
	var test_offsets: Array[Vector3] = [
		Vector3(2005.0, 0.0, 0.0),
		Vector3(0.0, -2100.0, 0.0),
		Vector3(0.0, 0.0, 2050.0),
		Vector3(1500.0, 1500.0, 1500.0), # diagonal > 2000m
		Vector3(-2200.0, 1800.0, -900.0)
	]
	
	for idx in range(test_offsets.size()):
		var offset: Vector3 = test_offsets[idx]
		ship.global_position = offset
		ship.linear_velocity = Vector3(6000.0, -8000.0, 1500.0) # 10,111 m/s
		ship.angular_velocity = Vector3(1.5, -2.2, 0.9)
		
		ship._physics_process(0.016667)
		var v_pre: Vector3 = ship.linear_velocity
		var w_pre: Vector3 = ship.angular_velocity
		var g_pre: Vector3 = ship.get_current_gravity()
		var alt_pre: float = ship.get_current_altitude()
		
		# Execute rebase
		var rebased: bool = fo.check_rebase()
		_assert(rebased, "Rebase triggered for test offset %d" % idx)
		
		var v_post: Vector3 = ship.linear_velocity
		var w_post: Vector3 = ship.angular_velocity
		
		_assert_near((v_post - v_pre).length(), 0.0, 1e-4, "Rebase %d: linear velocity conserved (< 1e-4)" % idx)
		_assert_near((w_post - w_pre).length(), 0.0, 1e-4, "Rebase %d: angular velocity conserved (< 1e-4)" % idx)
		
		# Check PhysicsServer3D directly
		var rid: RID = ship.get_rid()
		var v_srv: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
		var w_srv: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
		_assert_near((v_srv - v_pre).length(), 0.0, 1e-4, "Rebase %d: PhysicsServer3D velocity conserved" % idx)
		_assert_near((w_srv - w_pre).length(), 0.0, 1e-4, "Rebase %d: PhysicsServer3D angular velocity conserved" % idx)
		
		# Check altitude and gravity continuity
		var alt_post: float = ship.get_current_altitude()
		_assert_near(alt_post, alt_pre, 1e-3, "Rebase %d: altitude invariant under rebase" % idx)
		
		ship._physics_process(0.016667)
		var g_post: Vector3 = ship.get_current_gravity()
		_assert_near((g_post - g_pre).length(), 0.0, 1e-2, "Rebase %d: gravity continuous across rebase frame" % idx)
	
	# Rapid 100-rebase stress
	var ship_v: Vector3 = Vector3(100.0, -200.0, 300.0)
	ship.linear_velocity = ship_v
	for i in range(100):
		ship.position = Vector3(2001.0, 0.0, 0.0)
		fo.check_rebase()
		_assert_near((ship.linear_velocity - ship_v).length(), 0.0, 1e-4, "Rapid rebase step %d velocity invariance" % i)
	
	root.remove_child(ship)
	ship.free()
	pm.free()
	fo.free()

## -----------------------------------------------------------------------------
## ADV 3: Mathematical Exactness, C0 Continuity, & Singularity Hardening
## -----------------------------------------------------------------------------
func test_adv3_mathematical_continuity_and_singularities() -> void:
	print("\n--- ADV 3: Mathematical Exactness, C0 Continuity & Singularities ---")
	var planet: Vector3 = Vector3(1000.0, -2000.0, 3000.0)
	var R: float = 50_000.0
	var g0: float = 9.81
	
	# Analytical verification along 20 altitude samples from R to 10R
	for step in range(20):
		var r: float = R * (1.0 + float(step) * 0.5) # R, 1.5R, 2R, ..., 10.5R
		var test_dir: Vector3 = Vector3(1.0, 2.0, -2.0).normalized()
		var v_pos: Vector3 = planet + test_dir * r
		var g_vec: Vector3 = AtmosphereMath.calculate_gravity_acceleration(v_pos, planet, R, g0)
		
		var expected_mag: float = g0 * (R / r) * (R / r)
		var expected_vec: Vector3 = -test_dir * expected_mag
		
		_assert_near(g_vec.length(), expected_mag, 1e-4, "Sample r=%.1f*R magnitude matches analytical formula" % (r / R))
		_assert_vec3_near(g_vec, expected_vec, 1e-4, "Sample r=%.1f*R vector matches analytical direction" % (r / R))
	
	# C0 Continuity across surface boundary r = R
	var epsilons: Array[float] = [1.0, 0.1, 0.01, 0.001]
	var norm_dir: Vector3 = Vector3(0, 1, 0)
	for eps in epsilons:
		var pos_below: Vector3 = planet + norm_dir * (R - eps)
		var pos_above: Vector3 = planet + norm_dir * (R + eps)
		var g_below: Vector3 = AtmosphereMath.calculate_gravity_acceleration(pos_below, planet, R, g0)
		var g_above: Vector3 = AtmosphereMath.calculate_gravity_acceleration(pos_above, planet, R, g0)
		var jump: float = (g_above - g_below).length()
		_assert(jump < (2.0 * g0 * eps / R + 1e-4), "Boundary continuity jump %f is bounded by Lipschitz delta for eps=%f" % [jump, eps])
	
	# Singularity stress:
	# 1. Exact zero distance
	_assert(AtmosphereMath.calculate_gravity_acceleration(planet, planet, R, g0) == Vector3.ZERO, "Singularity r=0 returns ZERO")
	# 2. Distance strictly below 1e-6
	_assert(AtmosphereMath.calculate_gravity_acceleration(planet + Vector3(5e-7, 0, 0), planet, R, g0) == Vector3.ZERO, "r=5e-7 returns ZERO")
	# 3. Distance just above 1e-6 (tested around Vector3.ZERO to avoid float32 base offset cancellation)
	var g_threshold_1: Vector3 = AtmosphereMath.calculate_gravity_acceleration(Vector3(1.1e-6, 0, 0), Vector3.ZERO, R, g0)
	_assert_near(g_threshold_1.length(), g0, 1e-2, "r=1.1e-6 returns clamped surface gravity g0")
	var g_threshold_2: Vector3 = AtmosphereMath.calculate_gravity_acceleration(Vector3(1e-5, 0, 0), Vector3.ZERO, R, g0)
	_assert_near(g_threshold_2.length(), g0, 1e-3, "r=1e-5 returns clamped surface gravity g0")
	# 4. Zero / negative planet radius
	_assert(AtmosphereMath.calculate_gravity_acceleration(planet + Vector3(100, 0, 0), planet, 0.0, g0) == Vector3.ZERO, "R=0 returns ZERO")
	_assert(AtmosphereMath.calculate_gravity_acceleration(planet + Vector3(100, 0, 0), planet, -100.0, g0) == Vector3.ZERO, "R=-100 returns ZERO")
	# 5. Astronomical distance: r = 1e12 m (1 billion km)
	var g_astro: Vector3 = AtmosphereMath.calculate_gravity_acceleration(planet + Vector3(1e12, 0, 0), planet, R, g0)
	_assert(not is_nan(g_astro.x) and not is_inf(g_astro.x), "r=1e12 does not produce NaN/INF")
	_assert_near(g_astro.length(), 0.0, 1e-6, "r=1e12 approaches 0.0 gracefully")

## -----------------------------------------------------------------------------
## ADV 4: Orbital Freefall & Energy Conservation Across Rebases
## -----------------------------------------------------------------------------
func test_adv4_orbital_freefall_energy_conservation() -> void:
	print("\n--- ADV 4: Orbital Freefall & Energy Conservation Across Rebases ---")
	var ship: SpaceshipController = SpaceshipController.new()
	var pm: PlanetManager = PlanetManager.new()
	var fo: FloatingOrigin = FloatingOrigin.new()
	
	var R: float = 100_000.0
	var g0: float = 9.81
	var r_orbit: float = 150_000.0 # 50 km above surface (in vacuum)
	
	pm.planet_radius = R
	pm.planet_center_offset = Vector3.ZERO
	ship.planet_manager = pm
	ship.enable_planetary_gravity = true
	ship.surface_gravity = g0
	ship.mass = 2000.0
	
	fo.player_node = ship
	fo.planet_manager = pm
	
	# Analytical circular orbital speed: v_circ = sqrt(g(r) * r)
	# g(r) = g0 * (R / r)^2
	# v_circ = sqrt(g0 * R^2 / r)
	var v_circ: float = sqrt(g0 * R * R / r_orbit)
	
	# Initial orbital state in X-Y plane
	ship.position = Vector3(r_orbit, 0.0, 0.0)
	ship.linear_velocity = Vector3(0.0, v_circ, 0.0)
	
	# Specific orbital energy: epsilon = 0.5 * v^2 - mu / r
	var mu: float = g0 * R * R
	var energy_pre: float = 0.5 * ship.linear_velocity.length_squared() - mu / ship.position.length()
	
	# Simulate 10 orbital steps
	var dt: float = 0.016667
	for step in range(10):
		ship._physics_process(dt)
		# Semi-implicit Euler integration for orbit check
		ship.linear_velocity += (ship.get_current_gravity() / ship.mass) * dt
		ship.position += ship.linear_velocity * dt
	
	# Mid-orbit floating origin rebase of 2,000m
	var rebase_offset: Vector3 = Vector3(2000.0, 0.0, 0.0)
	fo.rebase(rebase_offset)
	
	# Relative orbital position: r_rel = ship.position - pm.planet_center_offset
	var r_rel: Vector3 = ship.position - pm.planet_center_offset
	var energy_post: float = 0.5 * ship.linear_velocity.length_squared() - mu / r_rel.length()
	
	_assert_near(energy_post, energy_pre, 1.0, "Specific orbital energy conserved across rebase (diff < 1.0 J/kg)")
	_assert_near(r_rel.length(), r_orbit, 50.0, "Relative orbital radius conserved across rebase")
	
	ship.free()
	pm.free()
	fo.free()

## -----------------------------------------------------------------------------
## ADV 5: Backward Compatibility (Default False)
## -----------------------------------------------------------------------------
func test_adv5_backward_compatibility() -> void:
	print("\n--- ADV 5: Backward Compatibility ---")
	var ship: SpaceshipController = SpaceshipController.new()
	_assert(ship.enable_planetary_gravity == false, "enable_planetary_gravity defaults to false")
	_assert_near(ship.surface_gravity, 9.81, 1e-4, "surface_gravity defaults to 9.81")
	
	ship.position = Vector3(0.0, 5000.0, 0.0)
	ship.linear_velocity = Vector3(0.0, 50.0, 0.0)
	ship.planet_radius = 50_000.0
	ship.planet_position = Vector3(0.0, 0.0, 0.0)
	
	ship._physics_process(0.016667)
	_assert(ship.get_current_gravity() == Vector3.ZERO, "Gravity force is strictly ZERO when disabled")
	_assert(ship.get_current_gravity_acceleration() == Vector3.ZERO, "Gravity acceleration is strictly ZERO when disabled")
	_assert_vec3_near(ship._net_force, ship.get_current_drag(), 1e-4, "Net force only contains drag and thrust when gravity is disabled")
	
	ship.free()

## -----------------------------------------------------------------------------
## ADV 6: Anti-Facade Dynamic Integrity Audit
## -----------------------------------------------------------------------------
func test_adv6_dynamic_integrity_audit() -> void:
	print("\n--- ADV 6: Anti-Facade Dynamic Integrity Audit ---")
	# Probe 100 pseudo-randomized scenarios to guarantee implementation is not hardcoded or facade
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 987654321
	
	for trial in range(100):
		var test_planet: Vector3 = Vector3(rng.randf_range(-1e5, 1e5), rng.randf_range(-1e5, 1e5), rng.randf_range(-1e5, 1e5))
		var test_radius: float = rng.randf_range(1000.0, 200_000.0)
		var test_g0: float = rng.randf_range(1.0, 50.0)
		var test_dist: float = rng.randf_range(0.1, 5.0) * test_radius
		var test_dir: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var test_pos: Vector3 = test_planet + test_dir * test_dist
		
		var g_calc: Vector3 = AtmosphereMath.calculate_gravity_acceleration(test_pos, test_planet, test_radius, test_g0)
		
		# Expected
		var r_eff: float = maxf(test_dist, test_radius)
		var expected_g_mag: float = test_g0 * (test_radius / r_eff) * (test_radius / r_eff)
		var expected_g_vec: Vector3 = -test_dir * expected_g_mag
		
		_assert_near(g_calc.length(), expected_g_mag, 1e-3, "Random trial %d magnitude check" % trial)
		_assert_vec3_near(g_calc, expected_g_vec, 1e-3, "Random trial %d vector check" % trial)
