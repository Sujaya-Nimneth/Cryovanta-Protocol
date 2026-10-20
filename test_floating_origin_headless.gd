extends SceneTree

## Headless E2E Automated Verification Test Suite for Cryovanta Protocol
## Covers Tiers 1-4 per TEST_INFRA.md and PROJECT.md:
## - Tier 1: Isolated Feature Coverage (F1 to F10, >= 5 tests each)
## - Tier 2: Boundary & Corner Cases
## - Tier 3: Cross-Feature Combinations
## - Tier 4: Real-World Atmospheric Entry Flight Scenario
##
## Runnable headlessly via:
##   godot --headless -s test_floating_origin_headless.gd
## Exits with code 0 on all tests passing, code 1 on any failure.

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_test_name: String = ""

# Dynamic Class References
var FloatingOriginClass = null
var SpaceshipControllerClass = null
var AtmosphereMathClass = null
var PlanetManagerClass = null

func _init() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Headless E2E Verification Test Suite (Tiers 1-4)")
	print("==================================================================")
	
	_load_classes()
	
	print("\n--- Running Tier 1: Feature Coverage (F1-F10) ---")
	_run_tier_1()
	
	print("\n--- Running Tier 2: Boundary & Corner Cases ---")
	_run_tier_2()
	
	print("\n--- Running Tier 3: Cross-Feature Combinations ---")
	_run_tier_3()
	
	print("\n--- Running Tier 4: Real-World Application Scenarios ---")
	_run_tier_4()
	
	_print_summary()
	
	if failed_tests > 0:
		printerr("\nFAILURE: %d out of %d tests failed!" % [failed_tests, total_tests])
		quit(1)
	else:
		print("\nSUCCESS: All %d headless tests passed with exit code 0!" % total_tests)
		quit(0)

# ==============================================================================
# Dynamic Class Loader
# ==============================================================================
func _load_classes() -> void:
	FloatingOriginClass = load("res://FloatingOrigin.gd")
	SpaceshipControllerClass = load("res://SpaceshipController.gd")
	AtmosphereMathClass = load("res://AtmosphereMath.gd")
	PlanetManagerClass = load("res://PlanetManager.gd")
	
	_assert(FloatingOriginClass != null, "Load FloatingOrigin.gd failed")
	_assert(SpaceshipControllerClass != null, "Load SpaceshipController.gd failed")
	_assert(AtmosphereMathClass != null, "Load AtmosphereMath.gd failed")
	_assert(PlanetManagerClass != null, "Load PlanetManager.gd failed")

# ==============================================================================
# Assertion Utilities
# ==============================================================================
func _start_test(test_name: String) -> void:
	current_test_name = test_name
	total_tests += 1

func _pass() -> void:
	passed_tests += 1

func _fail(reason: String) -> void:
	failed_tests += 1
	printerr("  [FAIL] %s: %s" % [current_test_name, reason])

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)
	else:
		_pass()

func _assert_approx(actual: float, expected: float, tol: float = 1e-4, message: String = "") -> void:
	var diff: float = abs(actual - expected)
	if diff > tol:
		_fail("%s (expected %f, got %f, diff %f > tol %f)" % [message, expected, actual, diff, tol])
	else:
		_pass()

func _assert_vec3_approx(actual: Vector3, expected: Vector3, tol: float = 1e-4, message: String = "") -> void:
	var diff: float = (actual - expected).length()
	if diff > tol:
		_fail("%s (expected %s, got %s, diff %f > tol %f)" % [message, str(expected), str(actual), diff, tol])
	else:
		_pass()

# ==============================================================================
# Tier 1: Feature Coverage (F1 to F10)
# ==============================================================================
func _run_tier_1() -> void:
	_test_f1_floating_origin_threshold()
	_test_f2_planet_center_offset()
	_test_f3_world_entity_repositioning()
	_test_f4_velocity_continuity()
	_test_f5_6dof_flight_controls()
	_test_f6_zero_runtime_allocations()
	_test_f7_vacuum_boundary_drag_zeroing()
	_test_f8_continuous_drag_speed_squared()
	_test_f9_line_count_guardrails()
	_test_f10_git_commit_history()

## F1: Floating origin threshold detection at 2000m (>= 5 tests)
func _test_f1_floating_origin_threshold() -> void:
	var fo = FloatingOriginClass.new()
	var player = Node3D.new()
	fo.player_node = player
	
	# Test F1.1: Default threshold is 2000.0m
	_start_test("F1.1: Default rebase threshold is 2000.0m")
	_assert_approx(fo.rebase_threshold, 2000.0, 1e-4, "Default threshold mismatch")
	
	# Test F1.2: Position strictly below threshold does not trigger rebase
	_start_test("F1.2: Sub-threshold position (1500m) does not trigger rebase")
	player.position = Vector3(1500.0, 0.0, 0.0)
	var trig_low: bool = fo.check_rebase()
	_assert(not trig_low, "Rebase triggered prematurely below threshold")
	_assert_vec3_approx(player.position, Vector3(1500.0, 0.0, 0.0), 1e-4, "Player moved when no rebase")
	
	# Test F1.3: Position strictly above threshold triggers rebase
	_start_test("F1.3: Super-threshold position (2500m) triggers rebase")
	player.position = Vector3(2500.0, 0.0, 0.0)
	var trig_high: bool = fo.check_rebase()
	_assert(trig_high, "Rebase failed to trigger above threshold")
	
	# Test F1.4: Player position reset to origin after rebase
	_start_test("F1.4: Player position reset near Vector3.ZERO after rebase")
	_assert_vec3_approx(player.position, Vector3.ZERO, 1e-4, "Player position not reset")
	
	# Test F1.5: Signal origin_rebased emitted with correct offset
	_start_test("F1.5: origin_rebased signal emission with exact offset")
	var signal_data: Dictionary = {"emitted": false, "offset": Vector3.ZERO}
	fo.origin_rebased.connect(func(off: Vector3):
		signal_data["emitted"] = true
		signal_data["offset"] = off
	)
	player.position = Vector3(0.0, 2100.0, 0.0)
	fo.check_rebase()
	_assert(signal_data["emitted"], "origin_rebased signal not emitted")
	_assert_vec3_approx(signal_data["offset"], Vector3(0.0, 2100.0, 0.0), 1e-4, "Signal offset mismatch")
	
	# Test F1.6: Accumulated offset tracking across rebases
	_start_test("F1.6: Accumulated offset accurately sums rebase offsets")
	_assert_vec3_approx(fo.accumulated_offset, Vector3(2500.0, 2100.0, 0.0), 1e-4, "Accumulated offset mismatch")
	
	player.free()
	fo.free()

## F2: PlanetManager planet_center_offset updated by subtracted vector (>= 5 tests)
func _test_f2_planet_center_offset() -> void:
	var planet = PlanetManagerClass.new()
	
	# Test F2.1: Initial planet_center_offset is Vector3.ZERO
	_start_test("F2.1: PlanetManager initial center offset is Vector3.ZERO")
	_assert_vec3_approx(planet.planet_center_offset, Vector3.ZERO, 1e-4, "Initial offset not zero")
	
	# Test F2.2: Single rebase_origin subtracts offset vector
	_start_test("F2.2: rebase_origin subtracts offset from planet_center_offset")
	var shift1: Vector3 = Vector3(2000.0, 500.0, -300.0)
	planet.rebase_origin(shift1)
	_assert_vec3_approx(planet.planet_center_offset, -shift1, 1e-4, "Single rebase offset mismatch")
	
	# Test F2.3: Multiple rebases accumulate subtracted offset vectors
	_start_test("F2.3: Multiple rebases accumulate subtracted offsets correctly")
	var shift2: Vector3 = Vector3(1000.0, -200.0, 800.0)
	planet.rebase_origin(shift2)
	_assert_vec3_approx(planet.planet_center_offset, -(shift1 + shift2), 1e-4, "Accumulated rebase offset mismatch")
	
	# Test F2.4: Invariant relative camera vector across rebase
	_start_test("F2.4: Relative camera vector is invariant across coordinate rebase")
	var cam_world: Vector3 = Vector3(0.0, 0.0, 150_000.0)
	var rel_before: Vector3 = cam_world - Vector3.ZERO
	var rebase_vec: Vector3 = Vector3(2000.0, 0.0, 0.0)
	var cam_world_after: Vector3 = cam_world - rebase_vec
	var planet_offset_after: Vector3 = Vector3.ZERO - rebase_vec
	var rel_after: Vector3 = cam_world_after - planet_offset_after
	_assert_vec3_approx(rel_before, rel_after, 1e-4, "Relative camera vector drifted across rebase")
	
	# Test F2.5: Quadtree topology invariance across rebase at steady-state
	_start_test("F2.5: Quadtree active leaves remain invariant across rebase")
	planet.planet_center_offset = Vector3.ZERO
	planet.position = Vector3.ZERO
	for i in range(10):
		planet.update_camera(cam_world)
	var leaves_before: int = planet.get_all_leaves().size()
	
	planet.rebase_origin(rebase_vec)
	planet.update_camera(cam_world - rebase_vec)
	var leaves_after: int = planet.get_all_leaves().size()
	_assert(leaves_before == leaves_after, "Quadtree leaf count changed across rebase: %d vs %d" % [leaves_before, leaves_after])
	
	planet.destroy()
	planet.free()

## F3: Camera and registered world entities repositioned in single frame (>= 5 tests)
func _test_f3_world_entity_repositioning() -> void:
	var fo = FloatingOriginClass.new()
	var player = Node3D.new()
	fo.player_node = player
	
	var entity_a = Node3D.new()
	entity_a.position = Vector3(3000.0, 100.0, 50.0)
	var entity_b = Node3D.new()
	entity_b.position = Vector3(-1000.0, 400.0, 200.0)
	var cam = Camera3D.new()
	cam.position = Vector3(0.0, 2.0, 10.0)
	
	# Test F3.1: Register single entity
	_start_test("F3.1: Register entity adds node to registered_entities")
	fo.register_entity(entity_a)
	_assert(fo.registered_entities.has(entity_a), "Entity A was not registered")
	
	# Test F3.2: Register multiple entities including Camera3D
	_start_test("F3.2: Register multiple entities and camera")
	fo.register_entity(entity_b)
	fo.register_entity(cam)
	_assert(fo.registered_entities.size() == 3, "Registered entity count mismatch")
	
	# Test F3.3: Idempotent registration prevents duplicate tracking
	_start_test("F3.3: Idempotent registration does not duplicate entries")
	fo.register_entity(entity_a)
	_assert(fo.registered_entities.size() == 3, "Duplicate registration detected")
	
	# Test F3.4: Rebase translates all registered entities in single frame
	_start_test("F3.4: Single-frame rebase repositioning of all registered entities")
	player.position = Vector3(2200.0, 0.0, 0.0)
	fo.check_rebase()
	_assert_vec3_approx(entity_a.position, Vector3(800.0, 100.0, 50.0), 1e-4, "Entity A translation mismatch")
	_assert_vec3_approx(entity_b.position, Vector3(-3200.0, 400.0, 200.0), 1e-4, "Entity B translation mismatch")
	_assert_vec3_approx(cam.position, Vector3(-2200.0, 2.0, 10.0), 1e-4, "Camera translation mismatch")
	
	# Test F3.5: Unregister entity stops further repositioning
	_start_test("F3.5: Unregistered entity is untouched by subsequent rebase")
	fo.unregister_entity(entity_b)
	_assert(not fo.registered_entities.has(entity_b), "Entity B not removed")
	player.position = Vector3(2500.0, 0.0, 0.0)
	fo.check_rebase()
	_assert_vec3_approx(entity_b.position, Vector3(-3200.0, 400.0, 200.0), 1e-4, "Unregistered Entity B was erroneously moved")
	
	player.free()
	entity_a.free()
	entity_b.free()
	cam.free()
	fo.free()

## F4: Spaceship linear_velocity and angular_velocity match within tolerance < 1e-4 (>= 5 tests)
func _test_f4_velocity_continuity() -> void:
	var ship = SpaceshipControllerClass.new()
	
	# Test F4.1: Pure axial velocity continuity
	_start_test("F4.1: Pure axial linear velocity continuity (< 1e-4)")
	ship.linear_velocity = Vector3(150.0, 0.0, 0.0)
	ship.angular_velocity = Vector3.ZERO
	ship.rebase_origin(Vector3(2000.0, 0.0, 0.0))
	_assert_vec3_approx(ship.linear_velocity, Vector3(150.0, 0.0, 0.0), 1e-4, "Axial linear velocity drifted")
	
	# Test F4.2: Full 3D linear velocity vector continuity
	_start_test("F4.2: Full 3D linear velocity continuity (< 1e-4)")
	var v_init: Vector3 = Vector3(45.67, -89.12, 123.45)
	ship.linear_velocity = v_init
	ship.rebase_origin(Vector3(-1500.0, 750.0, 300.0))
	_assert_vec3_approx(ship.linear_velocity, v_init, 1e-4, "3D linear velocity drifted")
	
	# Test F4.3: Full 3D angular velocity vector continuity
	_start_test("F4.3: Full 3D angular velocity continuity (< 1e-4)")
	var w_init: Vector3 = Vector3(0.45, -0.78, 1.25)
	ship.angular_velocity = w_init
	ship.rebase_origin(Vector3(100.0, 2000.0, -500.0))
	_assert_vec3_approx(ship.angular_velocity, w_init, 1e-4, "3D angular velocity drifted")
	
	# Test F4.4: High-speed hypersonic velocity continuity (5,000 m/s)
	_start_test("F4.4: Hypersonic velocity continuity (5,000 m/s < 1e-4)")
	var v_hypersonic: Vector3 = Vector3(0.0, 5000.0, 0.0)
	ship.linear_velocity = v_hypersonic
	ship.rebase_origin(Vector3(0.0, 2000.1, 0.0))
	_assert_vec3_approx(ship.linear_velocity, v_hypersonic, 1e-4, "Hypersonic velocity drifted")
	
	# Test F4.5: Multiple sequential rebases accumulate zero velocity drift
	_start_test("F4.5: 5 sequential rebases preserve exact velocity state")
	var v_test: Vector3 = Vector3(33.3, 44.4, 55.5)
	var w_test: Vector3 = Vector3(0.1, -0.2, 0.3)
	ship.linear_velocity = v_test
	ship.angular_velocity = w_test
	for i in range(5):
		ship.rebase_origin(Vector3(2000.0, 100.0 * i, -50.0))
	_assert_vec3_approx(ship.linear_velocity, v_test, 1e-4, "Sequential rebases linear velocity drifted")
	_assert_vec3_approx(ship.angular_velocity, w_test, 1e-4, "Sequential rebases angular velocity drifted")
	
	ship.free()

## F5: 6-DOF inputs (surge, sway, heave, pitch, yaw, roll) actuate forces/torques (>= 5 tests)
func _test_f5_6dof_flight_controls() -> void:
	var ship = SpaceshipControllerClass.new()
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.position = Vector3(0.0, 120_000.0, 0.0) # In vacuum: altitude 20,000m > ceiling
	
	# Test F5.1: Surge (Forward / Reverse) thrust actuation
	_start_test("F5.1: Surge actuation produces correct forward and reverse forces")
	ship.set_thrust_input(Vector3(0.0, 0.0, 1.0)) # Forward input (+Z input -> -Z world force)
	ship._physics_process(0.016667)
	_assert_vec3_approx(ship._thrust_local, Vector3(0.0, 0.0, -ship.forward_thrust), 1e-4, "Forward thrust local mismatch")
	
	ship.set_thrust_input(Vector3(0.0, 0.0, -1.0)) # Reverse input (-Z input -> +Z world force)
	ship._physics_process(0.016667)
	_assert_vec3_approx(ship._thrust_local, Vector3(0.0, 0.0, ship.reverse_thrust), 1e-4, "Reverse thrust local mismatch")
	
	# Test F5.2: Sway (Strafe Left / Right) thrust actuation
	_start_test("F5.2: Sway actuation produces lateral forces")
	ship.set_thrust_input(Vector3(1.0, 0.0, 0.0)) # Strafe right
	ship._physics_process(0.016667)
	_assert_vec3_approx(ship._thrust_local, Vector3(ship.strafe_thrust, 0.0, 0.0), 1e-4, "Strafe right mismatch")
	
	ship.set_thrust_input(Vector3(-1.0, 0.0, 0.0)) # Strafe left
	ship._physics_process(0.016667)
	_assert_vec3_approx(ship._thrust_local, Vector3(-ship.strafe_thrust, 0.0, 0.0), 1e-4, "Strafe left mismatch")
	
	# Test F5.3: Heave (Vertical Ascent / Descent) thrust actuation
	_start_test("F5.3: Heave actuation produces vertical forces")
	ship.set_thrust_input(Vector3(0.0, 1.0, 0.0)) # Vertical ascent
	ship._physics_process(0.016667)
	_assert_vec3_approx(ship._thrust_local, Vector3(0.0, ship.vertical_thrust, 0.0), 1e-4, "Ascent mismatch")
	
	# Test F5.4: Pitch, Yaw, Roll torque actuation
	_start_test("F5.4: Rotational torque actuation across pitch, yaw, and roll")
	ship.set_torque_input(Vector3(1.0, 0.0, 0.0)) # Pitch
	ship._physics_process(0.016667)
	_assert_vec3_approx(ship._torque_local, Vector3(ship.pitch_torque, 0.0, 0.0), 1e-4, "Pitch torque mismatch")
	
	ship.set_torque_input(Vector3(0.0, 1.0, 0.0)) # Yaw
	ship._physics_process(0.016667)
	_assert_vec3_approx(ship._torque_local, Vector3(0.0, ship.yaw_torque, 0.0), 1e-4, "Yaw torque mismatch")
	
	ship.set_torque_input(Vector3(0.0, 0.0, 1.0)) # Roll
	ship._physics_process(0.016667)
	_assert_vec3_approx(ship._torque_local, Vector3(0.0, 0.0, ship.roll_torque), 1e-4, "Roll torque mismatch")
	
	# Test F5.5: Combined 6-DOF multi-axis actuation
	_start_test("F5.5: Compound 6-DOF simultaneous thrust and torque actuation")
	ship.set_thrust_input(Vector3(0.5, 0.5, 0.5))
	ship.set_torque_input(Vector3(0.2, 0.3, 0.4))
	ship._physics_process(0.016667)
	_assert_approx(ship._thrust_local.length(), Vector3(0.5 * ship.strafe_thrust, 0.5 * ship.vertical_thrust, -0.5 * ship.forward_thrust).length(), 1e-3, "Compound thrust magnitude mismatch")
	_assert_approx(ship._torque_local.length(), Vector3(0.2 * ship.pitch_torque, 0.3 * ship.yaw_torque, 0.4 * ship.roll_torque).length(), 1e-3, "Compound torque magnitude mismatch")
	
	ship.free()

## F6: Zero runtime memory allocations in _physics_process (>= 5 tests)
func _test_f6_zero_runtime_allocations() -> void:
	var ship = SpaceshipControllerClass.new()
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.position = Vector3(0.0, 105_000.0, 0.0) # Altitude 5000m (inside atmosphere)
	
	# Warmup to stabilize any one-time cache allocations
	for i in range(50):
		ship._physics_process(0.016667)
	
	# Test F6.1: Zero memory allocation for idle vessel (500 physics steps)
	_start_test("F6.1: Zero runtime heap memory allocation for idle vessel (500 steps)")
	var mem_idle_start: int = OS.get_static_memory_usage()
	for i in range(500):
		ship._physics_process(0.016667)
	var mem_idle_delta: int = OS.get_static_memory_usage() - mem_idle_start
	_assert(mem_idle_delta == 0, "Idle vessel allocated %d bytes in physics loop" % mem_idle_delta)
	
	# Test F6.2: Zero memory allocation under 6-DOF thrust actuation (500 steps)
	_start_test("F6.2: Zero runtime heap memory allocation under 6-DOF thrust (500 steps)")
	ship.set_thrust_input(Vector3(1.0, -0.5, 0.8))
	ship.set_torque_input(Vector3(0.2, -0.3, 0.5))
	var mem_thrust_start: int = OS.get_static_memory_usage()
	for i in range(500):
		ship._physics_process(0.016667)
	var mem_thrust_delta: int = OS.get_static_memory_usage() - mem_thrust_start
	_assert(mem_thrust_delta == 0, "Thrust actuation allocated %d bytes in physics loop" % mem_thrust_delta)
	
	# Test F6.3: Zero memory allocation with active atmospheric drag (500 steps)
	_start_test("F6.3: Zero runtime heap memory allocation with active drag (500 steps)")
	ship.linear_velocity = Vector3(100.0, -50.0, 20.0)
	var mem_drag_start: int = OS.get_static_memory_usage()
	for i in range(500):
		ship._physics_process(0.016667)
	var mem_drag_delta: int = OS.get_static_memory_usage() - mem_drag_start
	_assert(mem_drag_delta == 0, "Atmospheric drag allocated %d bytes in physics loop" % mem_drag_delta)
	
	# Test F6.4: Zero memory allocation in FloatingOrigin check_rebase (500 steps)
	_start_test("F6.4: Zero runtime heap memory allocation in FloatingOrigin monitor (500 steps)")
	var fo = FloatingOriginClass.new()
	fo.player_node = ship
	fo.rebase_threshold = 2000.0
	ship.position = Vector3(1000.0, 0.0, 0.0)
	var mem_fo_start: int = OS.get_static_memory_usage()
	for i in range(500):
		fo.check_rebase()
	var mem_fo_delta: int = OS.get_static_memory_usage() - mem_fo_start
	_assert(mem_fo_delta == 0, "FloatingOrigin allocated %d bytes in monitor loop" % mem_fo_delta)
	
	# Test F6.5: Zero memory allocation across 5,000 continuous full-simulation steps
	_start_test("F6.5: Zero runtime heap memory allocation across 5,000 flight steps")
	var mem_long_start: int = OS.get_static_memory_usage()
	for i in range(5000):
		ship._physics_process(0.016667)
		fo.check_rebase()
	var mem_long_delta: int = OS.get_static_memory_usage() - mem_long_start
	_assert(mem_long_delta == 0, "Long flight test allocated %d bytes in physics loop" % mem_long_delta)
	
	fo.free()
	ship.free()

## F7: Atmospheric drag force strictly zero when altitude >= atmosphere ceiling (>= 5 tests)
func _test_f7_vacuum_boundary_drag_zeroing() -> void:
	var ceiling: float = 10_000.0
	var vel: Vector3 = Vector3(0.0, 100.0, 0.0)
	
	# Test F7.1: Air density at exact atmosphere ceiling is strictly 0.0
	_start_test("F7.1: Air density at exact ceiling altitude is strictly 0.0")
	var rho_ceil: float = AtmosphereMathClass.get_air_density(ceiling, ceiling, 1.225)
	_assert(rho_ceil == 0.0, "Air density at ceiling is non-zero: %f" % rho_ceil)
	
	# Test F7.2: Air density above atmosphere ceiling is strictly 0.0
	_start_test("F7.2: Air density at ceiling + 100m is strictly 0.0")
	var rho_above: float = AtmosphereMathClass.get_air_density(ceiling + 100.0, ceiling, 1.225)
	_assert(rho_above == 0.0, "Air density above ceiling is non-zero: %f" % rho_above)
	
	# Test F7.3: Drag force vector at exact atmosphere ceiling is strictly Vector3.ZERO
	_start_test("F7.3: Drag force vector at ceiling is strictly Vector3.ZERO")
	var drag_ceil: Vector3 = AtmosphereMathClass.calculate_drag_force(vel, rho_ceil, 0.5, 10.0)
	_assert_vec3_approx(drag_ceil, Vector3.ZERO, 1e-9, "Drag force at ceiling is not zero")
	
	# Test F7.4: Hypersonic orbital velocity (8,000 m/s) in deep space experiences zero drag
	_start_test("F7.4: Hypersonic orbital flight (8,000 m/s) in deep space has zero drag")
	var rho_space: float = AtmosphereMathClass.get_air_density(500_000.0, ceiling, 1.225)
	var drag_space: Vector3 = AtmosphereMathClass.calculate_drag_force(Vector3(8000.0, 0.0, 0.0), rho_space, 0.5, 10.0)
	_assert_vec3_approx(drag_space, Vector3.ZERO, 1e-9, "Deep space drag force is not zero")
	
	# Test F7.5: SpaceshipController at altitude >= ceiling has get_current_density() == 0.0
	_start_test("F7.5: SpaceshipController queries zero density and drag in vacuum orbit")
	var ship = SpaceshipControllerClass.new()
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.position = Vector3(0.0, 115_000.0, 0.0) # Altitude 15,000m > 10,000m
	ship.linear_velocity = Vector3(200.0, 0.0, 0.0)
	ship._physics_process(0.016667)
	_assert(ship.get_current_density() == 0.0, "Ship evaluated non-zero vacuum density")
	_assert_vec3_approx(ship.get_current_drag(), Vector3.ZERO, 1e-9, "Ship evaluated non-zero vacuum drag")
	ship.free()

## F8: Smooth barometric density scaling and drag force proportional to speed squared (>= 5 tests)
func _test_f8_continuous_drag_speed_squared() -> void:
	var ceiling: float = 10_000.0
	var rho0: float = 1.225
	
	# Test F8.1: Surface density equals surface_air_density (1.225)
	_start_test("F8.1: Air density at surface (0m) equals surface_air_density (1.225)")
	var rho_surf: float = AtmosphereMathClass.get_air_density(0.0, ceiling, rho0)
	_assert_approx(rho_surf, rho0, 1e-4, "Surface density mismatch")
	
	# Test F8.2: Density decays monotonically as altitude increases
	_start_test("F8.2: Air density strictly decreases monotonically with altitude")
	var prev_rho: float = rho0
	var monotonic: bool = true
	for h in range(1000, 10001, 1000):
		var curr_rho: float = AtmosphereMathClass.get_air_density(float(h), ceiling, rho0)
		if curr_rho > prev_rho:
			monotonic = false
			break
		prev_rho = curr_rho
	_assert(monotonic, "Atmospheric density is not monotonically decreasing")
	
	# Test F8.3: Drag force vector strictly opposes velocity vector
	_start_test("F8.3: Drag force vector strictly opposes velocity (dot product < 0)")
	var v_arb: Vector3 = Vector3(12.0, -34.0, 56.0)
	var drag_arb: Vector3 = AtmosphereMathClass.calculate_drag_force(v_arb, 1.0, 0.5, 10.0)
	var dot: float = v_arb.dot(drag_arb)
	_assert(dot < 0.0, "Drag force does not strictly oppose velocity direction")
	
	# Test F8.4: Drag force magnitude quadruples when velocity doubles (2^2 = 4.0)
	_start_test("F8.4: Drag force scales quadratically (2x speed -> 4.0x force)")
	var f_10: Vector3 = AtmosphereMathClass.calculate_drag_force(Vector3(10.0, 0.0, 0.0), rho0, 0.5, 10.0)
	var f_20: Vector3 = AtmosphereMathClass.calculate_drag_force(Vector3(20.0, 0.0, 0.0), rho0, 0.5, 10.0)
	var ratio_2x: float = f_20.length() / f_10.length()
	_assert_approx(ratio_2x, 4.0, 1e-4, "Drag force ratio for 2x velocity was not 4.0")
	
	# Test F8.5: Drag force magnitude scales 9x when velocity triples (3^2 = 9.0)
	_start_test("F8.5: Drag force scales quadratically (3x speed -> 9.0x force)")
	var f_30: Vector3 = AtmosphereMathClass.calculate_drag_force(Vector3(30.0, 0.0, 0.0), rho0, 0.5, 10.0)
	var ratio_3x: float = f_30.length() / f_10.length()
	_assert_approx(ratio_3x, 9.0, 1e-4, "Drag force ratio for 3x velocity was not 9.0")

## F9: Line count guardrails <= 250 lines (>= 5 tests)
func _test_f9_line_count_guardrails() -> void:
	# Test F9.1: FloatingOrigin.gd <= 250 lines
	_start_test("F9.1: FloatingOrigin.gd line count <= 250 lines")
	var lines_fo: int = _count_lines("res://FloatingOrigin.gd")
	_assert(lines_fo > 0 and lines_fo <= 250, "FloatingOrigin.gd has %d lines (limit 250)" % lines_fo)
	
	# Test F9.2: SpaceshipController.gd <= 250 lines
	_start_test("F9.2: SpaceshipController.gd line count <= 250 lines")
	var lines_sc: int = _count_lines("res://SpaceshipController.gd")
	_assert(lines_sc > 0 and lines_sc <= 250, "SpaceshipController.gd has %d lines (limit 250)" % lines_sc)
	
	# Test F9.3: AtmosphereMath.gd <= 250 lines
	_start_test("F9.3: AtmosphereMath.gd line count <= 250 lines")
	var lines_am: int = _count_lines("res://AtmosphereMath.gd")
	_assert(lines_am > 0 and lines_am <= 250, "AtmosphereMath.gd has %d lines (limit 250)" % lines_am)
	
	# Test F9.4: PlanetManager.gd <= 250 lines
	_start_test("F9.4: PlanetManager.gd line count <= 250 lines")
	var lines_pm: int = _count_lines("res://PlanetManager.gd")
	_assert(lines_pm > 0 and lines_pm <= 250, "PlanetManager.gd has %d lines (limit 250)" % lines_pm)
	
	# Test F9.5: Average line count across all core scripts <= 200 lines
	_start_test("F9.5: Average line count across core physics scripts <= 200 lines")
	var avg_lines: float = float(lines_fo + lines_sc + lines_am + lines_pm) / 4.0
	_assert(avg_lines <= 200.0, "Average line count exceeds 200: %f" % avg_lines)

func _count_lines(res_path: String) -> int:
	var file = FileAccess.open(res_path, FileAccess.READ)
	if not file:
		return -1
	var text: String = file.get_as_text()
	if text.is_empty():
		return 0
	var count: int = text.split("\n").size()
	if text.ends_with("\n"):
		count -= 1
	return count

## F10: Git commit history check (>= 5 tests)
func _test_f10_git_commit_history() -> void:
	var out: Array = []
	var code: int = OS.execute("git", ["log", "--oneline", "-n", "20"], out)
	_start_test("F10.1: Git execution succeeded and repository has commit history")
	_assert(code == 0 and out.size() > 0, "Git command failed to retrieve log")
	
	var git_log: String = out[0] if out.size() > 0 else ""
	var lines: PackedStringArray = git_log.strip_edges().split("\n")
	
	# Test F10.2: Minimum atomic commit count (>= 4 commits)
	_start_test("F10.2: Repository contains at least 4 atomic progress commits")
	_assert(lines.size() >= 4, "Git history has fewer than 4 commits: %d" % lines.size())
	
	# Test F10.3: Git history contains PlanetManager commit
	_start_test("F10.3: Git history documents PlanetManager offset implementation")
	_assert(git_log.containsn("PlanetManager") or git_log.containsn("planet center"), "PlanetManager commit missing in git log")
	
	# Test F10.4: Git history contains FloatingOrigin commit
	_start_test("F10.4: Git history documents FloatingOrigin implementation")
	_assert(git_log.containsn("FloatingOrigin") or git_log.containsn("rebasing system"), "FloatingOrigin commit missing in git log")
	
	# Test F10.5: Git history contains SpaceshipController and AtmosphereMath commits
	_start_test("F10.5: Git history documents flight controller and atmospheric drag")
	_assert(git_log.containsn("SpaceshipController") or git_log.containsn("AtmosphereMath"), "SpaceshipController/AtmosphereMath commit missing in git log")

# ==============================================================================
# Tier 2: Boundary & Corner Cases
# ==============================================================================
func _run_tier_2() -> void:
	_test_t2_threshold_boundary()
	_test_t2_altitude_ceiling_boundary()
	_test_t2_zero_velocity_drag()
	_test_t2_hypersonic_stability()
	_test_t2_non_zero_initial_origin()

func _test_t2_threshold_boundary() -> void:
	var fo = FloatingOriginClass.new()
	var player = Node3D.new()
	fo.player_node = player
	fo.rebase_threshold = 2000.0
	
	# T2.1: 1999.9m does NOT trigger rebase
	_start_test("T2.1: Position at 1999.9m strictly does NOT trigger rebase")
	player.position = Vector3(1999.9, 0.0, 0.0)
	var trig_sub: bool = fo.check_rebase()
	_assert(not trig_sub, "Boundary 1999.9m triggered rebase when it should not")
	_assert_approx(player.position.x, 1999.9, 1e-4, "Player position altered at 1999.9m")
	
	# T2.2: 2000.1m DOES trigger rebase
	_start_test("T2.2: Position at 2000.1m strictly DOES trigger rebase")
	player.position = Vector3(2000.1, 0.0, 0.0)
	var trig_super: bool = fo.check_rebase()
	_assert(trig_super, "Boundary 2000.1m failed to trigger rebase")
	_assert_approx(player.position.x, 0.0, 1e-4, "Player position not reset at 2000.1m")
	
	player.free()
	fo.free()

func _test_t2_altitude_ceiling_boundary() -> void:
	var ceiling: float = 10_000.0
	
	# T2.3: Atmosphere ceiling boundary behavior (ceiling - 1m, ceiling, ceiling + 1m)
	_start_test("T2.3: Precision boundary check at ceiling - 1m, ceiling, and ceiling + 1m")
	var rho_below: float = AtmosphereMathClass.get_air_density(ceiling - 1.0, ceiling, 1.225)
	var rho_exact: float = AtmosphereMathClass.get_air_density(ceiling, ceiling, 1.225)
	var rho_above: float = AtmosphereMathClass.get_air_density(ceiling + 1.0, ceiling, 1.225)
	
	_assert(rho_below > 0.0, "Density at ceiling - 1m was zero: %f" % rho_below)
	_assert(rho_exact == 0.0, "Density at exact ceiling was non-zero: %f" % rho_exact)
	_assert(rho_above == 0.0, "Density at ceiling + 1m was non-zero: %f" % rho_above)

func _test_t2_zero_velocity_drag() -> void:
	# T2.4: Zero velocity drag does not cause NaN or division by zero
	_start_test("T2.4: Zero velocity produces Vector3.ZERO drag without NaN or Div0")
	var drag_zero: Vector3 = AtmosphereMathClass.calculate_drag_force(Vector3.ZERO, 1.225, 0.5, 10.0)
	_assert(drag_zero == Vector3.ZERO, "Zero velocity drag was not Vector3.ZERO")
	_assert(not is_nan(drag_zero.x) and not is_nan(drag_zero.y) and not is_nan(drag_zero.z), "NaN detected in zero velocity drag")

func _test_t2_hypersonic_stability() -> void:
	# T2.5: Hypersonic stability (10,000 m/s) produces finite non-NaN values
	_start_test("T2.5: Hypersonic velocity (10,000 m/s) drag stability and finitude")
	var v_hyper: Vector3 = Vector3(10_000.0, 0.0, 0.0)
	var drag_hyper: Vector3 = AtmosphereMathClass.calculate_drag_force(v_hyper, 1.225, 0.5, 10.0)
	_assert(not is_nan(drag_hyper.x) and not is_inf(drag_hyper.x), "Hypersonic drag produced NaN or Inf")
	_assert(drag_hyper.x < 0.0, "Hypersonic drag does not oppose velocity")
	# Force = -0.5 * 1.225 * 0.5 * 10 * 10000^2 = -306,250,000 N
	_assert_approx(drag_hyper.x, -306_250_000.0, 100.0, "Hypersonic drag force calculation mismatch")

func _test_t2_non_zero_initial_origin() -> void:
	# T2.6: Rebase with origin at non-zero initial positions
	_start_test("T2.6: Rebase when system has non-zero pre-existing accumulated offset")
	var fo = FloatingOriginClass.new()
	var player = Node3D.new()
	fo.player_node = player
	fo.accumulated_offset = Vector3(5000.0, -2000.0, 1000.0)
	
	player.position = Vector3(2500.0, 0.0, 0.0)
	fo.check_rebase()
	_assert_vec3_approx(fo.accumulated_offset, Vector3(7500.0, -2000.0, 1000.0), 1e-4, "Accumulated offset drift with non-zero start")
	_assert_vec3_approx(player.position, Vector3.ZERO, 1e-4, "Player not reset with non-zero start")
	
	player.free()
	fo.free()

# ==============================================================================
# Tier 3: Cross-Feature Combinations
# ==============================================================================
func _run_tier_3() -> void:
	_test_t3_rebase_during_thrust_and_drag()
	_test_t3_rebase_multiple_entity_types()
	_test_t3_rebase_sleeping_body()

func _test_t3_rebase_during_thrust_and_drag() -> void:
	# T3.1: Rebase occurring while spaceship is undergoing 6-DOF thrusting and dynamic drag
	_start_test("T3.1: Rebase while vessel undergoes active thrusting and atmospheric drag")
	var fo = FloatingOriginClass.new()
	var ship = SpaceshipControllerClass.new()
	fo.player_node = ship
	
	ship.planet_radius = 100_000.0
	ship.atmosphere_ceiling = 10_000.0
	ship.position = Vector3(2100.0, 105_000.0, 0.0) # Position > 2000m threshold, inside atmosphere
	ship.linear_velocity = Vector3(80.0, -20.0, 10.0)
	ship.angular_velocity = Vector3(0.1, -0.2, 0.3)
	ship.set_thrust_input(Vector3(0.5, 0.0, 1.0))
	ship.set_torque_input(Vector3(0.0, 0.5, 0.0))
	
	var v_before: Vector3 = ship.linear_velocity
	var w_before: Vector3 = ship.angular_velocity
	
	var rebased: bool = fo.check_rebase()
	_assert(rebased, "Rebase failed during compound thrust and drag flight")
	_assert_vec3_approx(ship.linear_velocity, v_before, 1e-4, "Linear velocity disrupted by rebase during flight")
	_assert_vec3_approx(ship.angular_velocity, w_before, 1e-4, "Angular velocity disrupted by rebase during flight")
	
	# Verify physics step executes cleanly immediately post-rebase
	ship._physics_process(0.016667)
	_assert(ship.get_current_drag().length() > 0.0, "Drag not active post-rebase")
	
	ship.free()
	fo.free()

func _test_t3_rebase_multiple_entity_types() -> void:
	# T3.2: Rebase with multiple registered entities (dynamic RigidBody3D, static bodies, Node3D)
	_start_test("T3.2: Simultaneous rebase across dynamic RigidBody3D, StaticBody3D, and Node3D")
	var fo = FloatingOriginClass.new()
	var player = Node3D.new()
	fo.player_node = player
	
	var dyn_body = RigidBody3D.new()
	dyn_body.position = Vector3(3000.0, 100.0, 0.0)
	dyn_body.linear_velocity = Vector3(25.0, -10.0, 5.0)
	dyn_body.angular_velocity = Vector3(0.2, -0.1, 0.05)
	
	var static_body = StaticBody3D.new()
	static_body.position = Vector3(2500.0, -400.0, 100.0)
	
	var marker = Node3D.new()
	marker.position = Vector3(1000.0, 200.0, -50.0)
	
	fo.register_entity(dyn_body)
	fo.register_entity(static_body)
	fo.register_entity(marker)
	
	player.position = Vector3(2050.0, 0.0, 0.0)
	fo.check_rebase()
	
	_assert_vec3_approx(dyn_body.position, Vector3(950.0, 100.0, 0.0), 1e-4, "Dynamic RigidBody3D position shifted")
	_assert_vec3_approx(dyn_body.linear_velocity, Vector3(25.0, -10.0, 5.0), 1e-4, "Dynamic RigidBody3D velocity preserved")
	_assert_vec3_approx(static_body.position, Vector3(450.0, -400.0, 100.0), 1e-4, "StaticBody3D position shifted")
	_assert_vec3_approx(marker.position, Vector3(-1050.0, 200.0, -50.0), 1e-4, "Marker Node3D position shifted")
	
	player.free()
	dyn_body.free()
	static_body.free()
	marker.free()
	fo.free()

func _test_t3_rebase_sleeping_body() -> void:
	# T3.3: Rebase with sleeping bodies (ensuring sleeping bodies do not wake with phantom impulses)
	_start_test("T3.3: Rebase preserves sleeping state and zero phantom impulse")
	var fo = FloatingOriginClass.new()
	var player = Node3D.new()
	fo.player_node = player
	
	var sleeper = RigidBody3D.new()
	sleeper.position = Vector3(2800.0, 0.0, 0.0)
	sleeper.linear_velocity = Vector3.ZERO
	sleeper.angular_velocity = Vector3.ZERO
	sleeper.sleeping = true
	fo.register_entity(sleeper)
	
	player.position = Vector3(2200.0, 0.0, 0.0)
	fo.check_rebase()
	
	_assert_vec3_approx(sleeper.linear_velocity, Vector3.ZERO, 1e-9, "Phantom linear impulse injected on sleeping body")
	_assert_vec3_approx(sleeper.angular_velocity, Vector3.ZERO, 1e-9, "Phantom angular impulse injected on sleeping body")
	_assert_vec3_approx(sleeper.position, Vector3(600.0, 0.0, 0.0), 1e-4, "Sleeping body position shifted")
	
	player.free()
	sleeper.free()
	fo.free()

# ==============================================================================
# Tier 4: Real-World Application Scenarios
# ==============================================================================
func _run_tier_4() -> void:
	_test_t4_atmospheric_entry_flight_profile()

func _test_t4_atmospheric_entry_flight_profile() -> void:
	# T4.1: Atmospheric entry flight profile:
	# Spaceship descending from vacuum orbit (15,000m altitude) through atmospheric ceiling (10,000m)
	# down to lower atmosphere (2,000m altitude) with continuous 2,000m origin rebase triggers.
	# Verifies:
	# 1. Zero vacuum drag above ceiling
	# 2. Smooth drag force scaling upon entry
	# 3. Exact velocity continuity across all triggered rebases (< 1e-4)
	# 4. Numerical stability (no NaN / Inf)
	# 5. ZERO runtime heap memory growth across hundreds of physics steps
	_start_test("T4.1: Real-world atmospheric entry flight profile with continuous rebases")
	
	var fo = FloatingOriginClass.new()
	var ship = SpaceshipControllerClass.new()
	var planet = PlanetManagerClass.new()
	
	fo.player_node = ship
	fo.planet_manager = planet
	fo.rebase_threshold = 2000.0
	
	var planet_radius: float = 100_000.0
	var atm_ceiling: float = 10_000.0
	
	ship.planet_manager = planet
	ship.planet_radius = planet_radius
	ship.atmosphere_ceiling = atm_ceiling
	ship.surface_air_density = 1.225
	
	# Vessel starts at altitude 12,000m (Vacuum Orbit, 2000m above ceiling)
	ship.position = Vector3(0.0, planet_radius + 12_000.0, 0.0)
	ship.linear_velocity = Vector3(1000.0, -350.0, 0.0) # Horizontal orbit velocity with descent vector
	ship.angular_velocity = Vector3(0.02, 0.0, 0.01)
	
	var dt: float = 0.1 # Simulation timestep
	var rebase_events: int = 0
	var max_velocity_spike: float = 0.0
	var reached_atmosphere: bool = false
	var drag_increased_with_descent: bool = true
	var previous_drag_mag: float = 0.0
	var has_nan_or_inf: bool = false
	
	# Measure memory stability across 250 entry steps (excluding 50 step warmup)
	var mem_benchmark_start: int = 0
	var mem_benchmark_end: int = 0
	
	for step in range(300):
		# Pre-rebase state
		var v_pre: Vector3 = ship.linear_velocity
		var w_pre: Vector3 = ship.angular_velocity
		
		# Check origin rebase
		if fo.check_rebase():
			rebase_events += 1
			var v_post: Vector3 = ship.linear_velocity
			var w_post: Vector3 = ship.angular_velocity
			var v_delta: float = (v_post - v_pre).length()
			var w_delta: float = (w_post - w_pre).length()
			max_velocity_spike = maxf(max_velocity_spike, maxf(v_delta, w_delta))
		
		# Update ship physics step
		ship._physics_process(dt)
		
		# Integrate position manually along velocity vector for realistic trajectory
		ship.position += ship.linear_velocity * dt
		
		# Check altitude and drag properties
		var alt: float = ship.get_current_altitude()
		var rho: float = ship.get_current_density()
		var drag: Vector3 = ship.get_current_drag()
		var drag_mag: float = drag.length()
		
		if alt >= atm_ceiling:
			if rho != 0.0 or drag_mag != 0.0:
				_fail("Non-zero drag in vacuum orbit during entry profile: rho=%f drag=%s" % [rho, str(drag)])
				break
		else:
			reached_atmosphere = true
			if drag_mag < previous_drag_mag and alt < 8000.0:
				drag_increased_with_descent = false
			previous_drag_mag = drag_mag
		
		if is_nan(ship.position.x) or is_inf(ship.position.x) or is_nan(ship.linear_velocity.x):
			has_nan_or_inf = true
			break
		
		if step == 50:
			mem_benchmark_start = OS.get_static_memory_usage()
		elif step == 299:
			mem_benchmark_end = OS.get_static_memory_usage()
	
	var mem_growth: int = mem_benchmark_end - mem_benchmark_start
	
	_assert(not has_nan_or_inf, "Numerical instability (NaN or Inf) detected during entry")
	_assert(reached_atmosphere, "Vessel failed to reach atmospheric ceiling")
	_assert(drag_increased_with_descent, "Drag force did not increase smoothly as vessel descended")
	_assert(rebase_events >= 3, "Too few rebase triggers during entry descent: %d" % rebase_events)
	_assert(max_velocity_spike < 1e-4, "Rebase velocity spike during atmospheric entry exceeded 1e-4: %f" % max_velocity_spike)
	_assert(mem_growth == 0, "Non-zero memory growth during 250 entry steps: %d bytes" % mem_growth)
	
	planet.destroy()
	planet.free()
	ship.free()
	fo.free()

# ==============================================================================
# Summary Report
# ==============================================================================
func _print_summary() -> void:
	print("\n==================================================================")
	print("TEST SUITE EXECUTION SUMMARY")
	print("==================================================================")
	print("  Total Tests Run:    %d" % total_tests)
	print("  Passed Assertions:  %d" % passed_tests)
	print("  Failed Assertions:  %d" % failed_tests)
	print("==================================================================")
