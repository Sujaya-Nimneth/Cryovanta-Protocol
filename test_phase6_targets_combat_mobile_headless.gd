extends SceneTree

## Phase 6 headless verification for pooled targets, impacts, combat, and mobile input.
## Run with: godot --headless -s test_phase6_targets_combat_mobile_headless.gd

const DT: float = 1.0 / 120.0

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Phase 6 Headless Verification Suite (Tiers 1-5)")
	print("==================================================================")
	await process_frame
	_run_tier_1()
	await _run_tier_2()
	await _run_tier_3()
	await _run_tier_4()
	await _run_tier_5()
	_print_summary()
	quit(0 if failed_assertions == 0 else 1)

func _start_test(test_name: String) -> void:
	current_test_name = test_name
	print("  [TEST] %s" % test_name)

func _assert(condition: bool, message: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("    [FAIL] %s: %s" % [current_test_name, message])

func _assert_int(actual: int, expected: int, message: String) -> void:
	_assert(actual == expected, "%s (expected %d, got %d)" % [message, expected, actual])

func _assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assert(absf(actual - expected) <= tolerance, "%s (expected %.8f, got %.8f)" % [
		message, expected, actual
	])

func _assert_vec3(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> void:
	_assert(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [
		message, str(expected), str(actual)
	])

func _print_summary() -> void:
	print("\n==================================================================")
	print("PHASE 6 TEST SUITE EXECUTION SUMMARY")
	print("==================================================================")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	print("==================================================================")
	if failed_assertions == 0:
		print("SUCCESS: All %d assertions passed with exit code 0!" % total_assertions)
	else:
		printerr("FAILURE: %d out of %d assertions failed!" % [
			failed_assertions, total_assertions
		])

func _instantiate_sim() -> Node:
	var packed: PackedScene = load("res://main.tscn")
	var sim: Node = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	return sim

func _dispose_sim(sim: Node) -> void:
	if sim == null:
		return
	sim.destroy()
	if sim.get_parent() == get_root():
		get_root().remove_child(sim)
	sim.free()

func _run_tier_1() -> void:
	print("\n--- Tier 1: Fixed Target and Impact Pool Lifecycles ---")
	_start_test("Tier 1.1: 32-slot target preallocation and O(1) reuse")
	var targets: TargetPoolManager = TargetPoolManager.new()
	get_root().add_child(targets)
	_assert_int(targets.POOL_SIZE, 32, "Target POOL_SIZE")
	_assert_int(targets.TARGET_COLLISION_LAYER, 4, "Target collision layer")
	_assert_int(targets.bodies.size(), 32, "Target body count")
	_assert_int(targets.markers.size(), 32, "Target marker count")
	_assert_int(targets.positions.size(), 32, "Target position buffer")
	_assert_int(targets.velocities.size(), 32, "Target velocity buffer")
	_assert_int(targets.health.size(), 32, "Target health buffer")
	var ids: Array[int] = []
	for i in range(32):
		var tid: int = targets.spawn_target(Vector3(float(i), 10.0, -5.0), Vector3.RIGHT)
		_assert(tid >= 0 and tid < 32 and not ids.has(tid), "Target slot %d is unique" % i)
		ids.append(tid)
		_assert_int(targets.bodies[tid].collision_layer, 4, "Target body uses layer 4")
		_assert(not targets.shapes[tid].disabled, "Spawned target collider is enabled")
		_assert(targets.markers[tid].visible, "Spawned target marker is visible")
	_assert_int(targets.active_count, 32, "All target slots active")
	_assert_int(targets.spawn_target(Vector3.ZERO), -1, "Exhausted target spawn returns -1")
	_assert(targets.release_target(ids[7]), "Target release succeeds")
	_assert_int(targets.spawn_target(Vector3.ZERO), ids[7], "Released target slot reused")
	_assert(not targets.release_target(-1), "Negative target release rejected")
	_assert(not targets.release_target(32), "Out-of-range target release rejected")
	_assert(targets.verify_integrity()["is_valid"], "Target integrity after churn")
	targets.clear()
	_assert_int(targets.active_count, 0, "Target clear releases all slots")
	_assert(targets.verify_integrity()["is_valid"], "Target integrity after clear")

	_start_test("Tier 1.2: Target motion, damage, auto-release, and 2,000 m rebase")
	var moving_id: int = targets.spawn_target(Vector3(10.0, 20.0, 30.0), Vector3(100.0, -20.0, 5.0), 100.0)
	targets.step_targets(0.5)
	_assert_vec3(targets.get_target_position(moving_id), Vector3(60.0, 10.0, 32.5), 1e-5,
		"Target integrates velocity")
	_assert_vec3(targets.bodies[moving_id].position, targets.get_target_position(moving_id), 1e-6,
		"Target body follows state")
	_assert_vec3(targets.markers[moving_id].position, targets.get_target_position(moving_id), 1e-6,
		"Target marker follows state")
	_assert(not targets.apply_damage(moving_id, 50.0), "50 damage does not destroy 100 HP")
	_assert_approx(targets.health[moving_id], 50.0, 1e-6, "Target health decremented")
	_assert(targets.apply_damage(moving_id, 50.0), "Second 50 damage destroys target")
	_assert_int(targets.active_count, 0, "Destroyed target auto-released")
	_assert_int(targets.find_target_by_collider(targets.bodies[moving_id]), -1,
		"Released target is not discoverable")
	var rebase_id: int = targets.spawn_target(Vector3(2_500.0, -400.0, 800.0), Vector3.ZERO, 10.0)
	var offset: Vector3 = Vector3(2_000.0, 0.0, -500.0)
	targets.rebase_origin(offset)
	_assert_vec3(targets.get_target_position(rebase_id), Vector3(500.0, -400.0, 1_300.0), 1e-5,
		"Target shifts by -offset")
	_assert_vec3(targets.bodies[rebase_id].position, targets.get_target_position(rebase_id), 1e-6,
		"Target body follows rebase")
	_assert(targets.verify_integrity()["is_valid"], "Target integrity after rebase")
	targets.clear()

	_start_test("Tier 1.3: 32-slot impact lifecycle, decay, and rebase")
	var impacts: ImpactEffectPoolManager = ImpactEffectPoolManager.new()
	get_root().add_child(impacts)
	_assert_int(impacts.POOL_SIZE, 32, "Impact POOL_SIZE")
	_assert_int(impacts.markers.size(), 32, "Impact marker count")
	for i in range(32):
		_assert(impacts.spawn_effect(Vector3(float(i), 0.0, 0.0), 0.35) >= 0,
			"Impact slot %d acquired" % i)
	_assert_int(impacts.active_count, 32, "All impact slots active")
	_assert_int(impacts.spawn_effect(Vector3.ZERO), -1, "Exhausted impact spawn returns -1")
	_assert(impacts.release_effect(0), "Impact release succeeds")
	_assert_int(impacts.spawn_effect(Vector3.ZERO), 0, "Released impact slot reused")
	_assert(not impacts.release_effect(-1), "Negative impact release rejected")
	_assert(not impacts.release_effect(32), "Out-of-range impact release rejected")
	impacts.clear()
	var decay_id: int = impacts.spawn_effect(Vector3(2_500.0, 0.0, 0.0), 0.35)
	var initial_scale: Vector3 = impacts.markers[decay_id].scale
	impacts.step_effects(0.1)
	_assert(impacts.markers[decay_id].scale.x > initial_scale.x, "Impact expands as it decays")
	impacts.step_effects(0.25)
	_assert_int(impacts.active_count, 0, "Expired impact auto-released")
	var rebase_effect: int = impacts.spawn_effect(Vector3(2_500.0, 100.0, -500.0), 1.0)
	impacts.rebase_origin(Vector3(2_000.0, 0.0, 500.0))
	_assert_vec3(impacts.positions[rebase_effect], Vector3(500.0, 100.0, -1_000.0), 1e-5,
		"Impact shifts by -offset")
	_assert(impacts.verify_integrity()["is_valid"], "Impact integrity after churn")
	impacts.clear()

	_start_test("Tier 1.4: Pool stepping has zero static memory growth")
	for i in range(16):
		targets.spawn_target(Vector3(0.0, 100_000.0 + float(i), 0.0), Vector3(30.0, -2.0, 1.0), 1e9)
		impacts.spawn_effect(Vector3(0.0, 100_000.0 + float(i), 0.0), 1e9)
	for i in range(200):
		targets.step_targets(DT)
		impacts.step_effects(DT)
	var before: int = OS.get_static_memory_usage()
	for i in range(2_000):
		targets.step_targets(DT)
		impacts.step_effects(DT)
	var after: int = OS.get_static_memory_usage()
	_assert(after - before <= 0, "Pool stepping static memory delta is %d bytes" % (after - before))
	_assert(targets.verify_integrity()["is_valid"], "Target integrity after stress")
	_assert(impacts.verify_integrity()["is_valid"], "Impact integrity after stress")
	targets.clear()
	impacts.clear()
	get_root().remove_child(targets)
	get_root().remove_child(impacts)
	targets.free()
	impacts.free()

func _run_tier_2() -> void:
	print("\n--- Tier 2: Projectile Hits, Damage, and Impact Bursts ---")
	_start_test("Tier 2.1: Projectile raycast damages a pooled target")
	var sim: Node = _instantiate_sim()
	await physics_frame
	sim.planet_manager.max_lod = 1
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.ship.global_position = Vector3.ZERO
	sim.ship.linear_velocity = Vector3.ZERO
	var target_id: int = sim.target_pool.spawn_target(
		Vector3(0.0, 0.0, -30.0), Vector3.ZERO, 100.0
	)
	var target_body: StaticBody3D = sim.target_pool.bodies[target_id]
	await physics_frame
	await physics_frame
	var space_state: PhysicsDirectSpaceState3D = get_root().get_world_3d().direct_space_state
	_assert_vec3(target_body.global_position, Vector3(0.0, 0.0, -30.0), 1e-5,
		"Target body transform syncs on spawn")
	var immediate_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	immediate_query.from = Vector3(0.0, 0.0, 10.0)
	immediate_query.to = Vector3(0.0, 0.0, -40.0)
	immediate_query.collision_mask = 5
	immediate_query.collide_with_bodies = true
	var immediate_hit: Dictionary = space_state.intersect_ray(immediate_query)
	_assert(not immediate_hit.is_empty() and immediate_hit["collider"] == target_body,
		"Same-frame raycast sees the spawned target collider")
	_assert_int(sim.projectile_pool.DEFAULT_COLLISION_MASK, 5, "Projectile collision mask")
	_assert_int(sim.projectile_pool._ray_query.collision_mask, 5, "Projectile query mask")
	_assert(sim.projectile_pool.target_pool == sim.target_pool, "Projectile pool links targets")
	_assert(sim.projectile_pool.impact_pool == sim.impact_pool, "Projectile pool links impacts")
	sim.projectile_pool.clear()
	var projectile_id: int = sim.projectile_pool.spawn_projectile(
		Vector3.ZERO, Vector3(0.0, 0.0, -600.0), 5.0
	)
	_assert(projectile_id >= 0, "Projectile acquired")
	var impacts: int = sim.projectile_pool.step_projectiles(0.1, space_state)
	_assert_int(impacts, 1, "Projectile registered one target impact")
	_assert_approx(sim.target_pool.health[target_id], 50.0, 1e-5, "First hit applies 50 damage")
	_assert_int(sim.target_pool.active_count, 1, "Target survives first hit")
	_assert_int(sim.projectile_pool.active_count, 0, "Projectile released on impact")
	_assert_int(sim.impact_pool.active_count, 1, "Impact burst spawned automatically")
	_assert_vec3(sim.impact_pool.positions[0], sim.target_pool.get_target_position(target_id) + Vector3(0, 0, 3),
		1e-4, "Impact burst appears at the hit surface")
	_assert(sim.impact_pool.verify_integrity()["is_valid"], "Impact pool integrity after hit")

	_start_test("Tier 2.2: Two 50-damage hits destroy and auto-release the target")
	projectile_id = sim.projectile_pool.spawn_projectile(
		Vector3.ZERO, Vector3(0.0, 0.0, -600.0), 5.0
	)
	_assert(projectile_id >= 0, "Second projectile acquired")
	impacts = sim.projectile_pool.step_projectiles(0.1, space_state)
	_assert_int(impacts, 1, "Second projectile registered one target impact")
	_assert_int(sim.target_pool.active_count, 0, "Target auto-released at zero health")
	_assert(sim.target_pool.shapes[target_id].disabled, "Destroyed target collider disabled")
	_assert_int(sim.impact_pool.active_count, 2, "Second impact burst spawned")
	_assert(sim.target_pool.verify_integrity()["is_valid"], "Target pool integrity after destruction")
	_assert(sim.projectile_pool.verify_integrity()["is_valid"], "Projectile pool integrity after hits")
	_dispose_sim(sim)

func _run_tier_3() -> void:
	print("\n--- Tier 3: Ballistic Lead Solving, Target Lock, and HUD Tracking ---")
	_start_test("Tier 3.1: Lead solver intercepts a crossing target")
	var shooter_pos: Vector3 = Vector3.ZERO
	var shooter_vel: Vector3 = Vector3(0.0, 0.0, -100.0)
	var target_pos: Vector3 = Vector3(600.0, 0.0, -400.0)
	var target_vel: Vector3 = Vector3(0.0, 120.0, 0.0)
	var lead: Vector3 = SpaceshipWeaponSystem.calculate_lead_position(
		shooter_pos, shooter_vel, target_pos, target_vel, 800.0
	)
	var rel_pos: Vector3 = target_pos - shooter_pos
	var rel_vel: Vector3 = target_vel - shooter_vel
	var qa: float = rel_vel.length_squared() - 800.0 * 800.0
	var qb: float = 2.0 * rel_pos.dot(rel_vel)
	var qc: float = rel_pos.length_squared()
	var disc: float = qb * qb - 4.0 * qa * qc
	var sqrt_d: float = sqrt(disc)
	var t1: float = (-qb - sqrt_d) / (2.0 * qa)
	var t2: float = (-qb + sqrt_d) / (2.0 * qa)
	var intercept_time: float = t1 if t1 > 0.0 and (t2 <= 0.0 or t1 < t2) else t2
	var expected: Vector3 = target_pos + target_vel * intercept_time
	var intercept_error: float = lead.distance_to(expected)
	_assert(intercept_error < 1.0,
		"Quadratic lead intercept error %.6f m is below 1 m" % intercept_error)
	_assert_approx(intercept_time, 0.856395, 1e-4, "Quadratic positive root")
	var stationary: Vector3 = SpaceshipWeaponSystem.calculate_lead_position(
		Vector3.ZERO, Vector3.ZERO, Vector3(100.0, 0.0, 0.0), Vector3.ZERO, 0.0
	)
	_assert_vec3(stationary, Vector3(100.0, 0.0, 0.0), 1e-6,
		"Zero muzzle speed clamps safely")

	_start_test("Tier 3.2: Nearest active target acquisition")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.ship.global_position = Vector3.ZERO
	_assert_int(sim.weapon_system.acquire_nearest_target(), -1,
		"No active target returns -1")
	var far_id: int = sim.target_pool.spawn_target(Vector3(900.0, 0.0, 0.0))
	var near_id: int = sim.target_pool.spawn_target(Vector3(120.0, 0.0, 0.0))
	var mid_id: int = sim.target_pool.spawn_target(Vector3(-400.0, 0.0, 0.0))
	_assert_int(sim.weapon_system.acquire_nearest_target(), near_id,
		"Nearest target locked")
	_assert_int(sim.weapon_system.locked_target_id, near_id, "Locked ID persisted")
	sim.target_pool.release_target(near_id)
	_assert_int(sim.weapon_system.acquire_nearest_target(), mid_id,
		"Released target is skipped")
	_assert_int(sim.weapon_system.acquire_nearest_target(sim.target_pool), mid_id,
		"Override pool uses the same resolver")
	_assert_int(sim.target_pool.active_count, 2, "Two targets remain active")
	_assert(far_id >= 0 and mid_id >= 0, "Target fixture acquired")

	_start_test("Tier 3.3: HUD tracks target and lead positions across a rebase")
	sim.ship.global_position = Vector3.ZERO
	sim.ship.linear_velocity = Vector3.ZERO
	sim.target_pool.clear()
	var hud_target: int = sim.target_pool.spawn_target(
		Vector3(500.0, 50.0, -300.0), Vector3(10.0, 20.0, 0.0), 100.0
	)
	_assert_int(sim.weapon_system.acquire_nearest_target(), hud_target, "HUD fixture locked")
	sim.step_simulation(DT)
	_assert_int(sim.hud.locked_target_id, hud_target, "HUD mirrors locked target")
	_assert_vec3(sim.hud.locked_target_pos, sim.target_pool.get_target_position(hud_target), 1e-5,
		"HUD target position mirrors pool")
	var expected_lead: Vector3 = SpaceshipWeaponSystem.calculate_lead_position(
		sim.ship.global_position, sim.ship.linear_velocity,
		sim.hud.locked_target_pos, sim.target_pool.get_target_velocity(hud_target)
	)
	_assert_vec3(sim.hud.locked_lead_pos, expected_lead, 1e-5, "HUD lead position mirrors solver")
	var target_before: Vector3 = sim.hud.locked_target_pos
	var lead_before: Vector3 = sim.hud.locked_lead_pos
	var offset: Vector3 = Vector3(2_000.0, -250.0, 400.0)
	sim.floating_origin.rebase(offset)
	_assert_vec3(sim.hud.locked_target_pos, target_before - offset, 1e-5,
		"HUD target position shifts on rebase")
	_assert_vec3(sim.hud.locked_lead_pos, lead_before - offset, 1e-5,
		"HUD lead position shifts on rebase")
	_assert_vec3(sim.target_pool.get_target_position(hud_target),
		target_before - offset, 1e-5, "Pool target shifts with the HUD")
	_assert(sim.camera.is_inside_tree() and sim.camera.current, "HUD camera is active in-tree")
	sim.hud._surface.queue_redraw()
	await process_frame
	await process_frame
	_assert_int(sim.hud.last_drawn_target_reticles, 2,
		"HUD draws target lock box and lead reticle")
	sim.weapon_system.locked_target_id = -1
	sim.step_simulation(DT)
	_assert_int(sim.weapon_system.locked_target_id, hud_target,
		"Simulation reacquires a cleared lock")
	_assert_int(sim.hud.locked_target_id, hud_target, "HUD mirrors reacquired lock")

	_start_test("Tier 3.4: Destroyed lock auto-refreshes to the next target")
	var next_target: int = sim.target_pool.spawn_target(
		Vector3(-200.0, 20.0, -250.0), Vector3.ZERO, 100.0
	)
	sim.weapon_system.locked_target_id = hud_target
	_assert(sim.target_pool.apply_damage(hud_target, 100.0), "Locked target destroyed")
	sim.step_simulation(DT)
	_assert_int(sim.weapon_system.locked_target_id, next_target,
		"Destroyed lock reacquires the remaining target")
	_assert_int(sim.hud.locked_target_id, next_target, "HUD follows the refreshed lock")
	sim.target_pool.apply_damage(next_target, 100.0)
	sim.step_simulation(DT)
	_assert_int(sim.weapon_system.locked_target_id, -1, "Empty target pool clears the lock")
	_assert_int(sim.hud.locked_target_id, -1, "HUD clears the empty target lock")
	_dispose_sim(sim)

func _run_tier_4() -> void:
	print("\n--- Tier 4: Android Dual-Stick Mapping and Simulation Telemetry ---")
	_start_test("Tier 4.1: Radial deadzone filtering and clamping")
	var touch: MobileTouchController = MobileTouchController.new()
	touch.deadzone = 0.1
	_assert(not touch.enabled, "Touch controls start disabled")
	touch.set_virtual_sticks(Vector2(1.0, 1.0), Vector2(-1.0, 1.0), 1.0, -1.0)
	_assert_vec3(touch.thrust_output, Vector3.ZERO, 1e-9, "Disabled touch emits no thrust")
	_assert_vec3(touch.torque_output, Vector3.ZERO, 1e-9, "Disabled touch emits no torque")
	touch.enabled = true
	touch.set_virtual_sticks(Vector2(0.05, -0.05), Vector2(0.0, 0.08), 0.05, -0.08)
	_assert_vec3(touch.thrust_output, Vector3.ZERO, 1e-9, "Inside deadzone maps to zero")
	_assert_vec3(touch.torque_output, Vector3.ZERO, 1e-9, "Torque deadzone maps to zero")
	touch.set_virtual_sticks(Vector2(0.6, -0.8), Vector2(-0.3, 0.4), 1.0, -1.0)
	_assert_approx(touch.left_stick.length(), 1.0, 1e-6, "Left stick radially normalized")
	_assert_approx(touch.right_stick.length(), 0.44444445, 1e-6, "Right stick radially filtered")
	_assert_approx(touch.vertical_axis, 1.0, 1e-9, "Vertical axis clamps high")
	_assert_approx(touch.roll_axis, -1.0, 1e-9, "Roll axis clamps low")
	_assert_vec3(touch.thrust_output, Vector3(0.6, 1.0, -0.8), 1e-6,
		"Thrust maps strafe/vertical/forward")
	_assert_vec3(touch.torque_output, Vector3(0.355556, -0.266667, -1.0), 1e-6,
		"Torque maps pitch/yaw/roll")

	_start_test("Tier 4.2: Virtual sticks drive SpaceshipController in manual mode")
	var ship: SpaceshipController = SpaceshipController.new()
	ship.process_user_input = false
	ship.set_physics_process(false)
	ship.freeze = true
	ship.mass = 1_000.0
	get_root().add_child(ship)
	ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	touch.set_virtual_sticks(Vector2(0.5, -1.0), Vector2(0.75, -0.5), 0.25, 0.9)
	touch.apply_to_ship(ship)
	_assert_vec3(ship.thrust_input, touch.thrust_output, 1e-9, "Touch thrust reaches ship")
	_assert_vec3(ship.torque_input, touch.torque_output, 1e-9, "Touch torque reaches ship")
	ship._apply_flight_forces()
	_assert(ship.get_current_net_force().length() > 0.0, "Mapped thrust produces flight force")
	get_root().remove_child(ship)
	ship.free()

	_start_test("Tier 4.3: Simulation wiring and target/impact telemetry")
	var sim: Node = _instantiate_sim()
	await process_frame
	sim.floating_origin.rebase_threshold = 1.0e12
	_assert(sim.target_pool != null and sim.target_pool.get_parent() == sim, "TargetPool is wired")
	_assert(sim.impact_pool != null and sim.impact_pool.get_parent() == sim, "ImpactPool is wired")
	_assert(sim.touch_controller != null, "MobileTouchController is wired")
	_assert(sim.floating_origin.origin_rebased.is_connected(sim.target_pool.rebase_origin),
		"TargetPool listens to origin rebases")
	_assert(sim.floating_origin.origin_rebased.is_connected(sim.impact_pool.rebase_origin),
		"ImpactPool listens to origin rebases")
	sim.target_pool.spawn_target(Vector3(100.0, 0.0, 0.0), Vector3.RIGHT * 10.0, 100.0)
	sim.target_pool.spawn_target(Vector3(-100.0, 0.0, 0.0), Vector3.ZERO, 100.0)
	sim.impact_pool.spawn_effect(Vector3(50.0, 0.0, 0.0), 1.0)
	sim.weapon_system.acquire_nearest_target()
	sim.step_simulation(DT)
	_assert_int(sim.telemetry.active_targets, 2, "Telemetry target count")
	_assert_int(sim.telemetry.active_impacts, 1, "Telemetry impact count")
	_assert_int(sim.telemetry.active_targets, sim.target_pool.active_count,
		"Telemetry mirrors target pool")
	_assert_int(sim.telemetry.active_impacts, sim.impact_pool.active_count,
		"Telemetry mirrors impact pool")
	_assert(sim.hud != null and sim.hud.locked_target_id >= 0, "HUD can read the live pool")

	_start_test("Tier 4.4: Mobile manual input through step_simulation")
	sim.ship.global_position = Vector3.ZERO
	sim.ship.global_transform.basis = Basis.IDENTITY
	sim.ship.linear_velocity = Vector3.ZERO
	sim.ship.angular_velocity = Vector3.ZERO
	sim.ship.process_user_input = true
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_MANUAL)
	sim.touch_controller.enabled = true
	sim.touch_controller.set_virtual_sticks(Vector2(0.0, 1.0), Vector2(0.0, 0.0), 0.0, 0.0)
	sim.step_simulation(DT)
	_assert_vec3(sim.ship.thrust_input, Vector3(0.0, 0.0, 1.0), 1e-9,
		"Manual mobile thrust survives simulation step")
	_assert(sim.ship.get_current_net_force().dot(-sim.ship.global_transform.basis.z) > 0.0,
		"Mobile forward stick accelerates the vessel")

	_start_test("Tier 4.5: 1,000 ticks with zero static memory growth")
	sim.ship.process_user_input = false
	sim.ship.linear_velocity = Vector3.ZERO
	for i in range(120):
		sim.step_simulation(DT)
	var memory_before: int = OS.get_static_memory_usage()
	for i in range(1_000):
		sim.step_simulation(DT)
	var memory_after: int = OS.get_static_memory_usage()
	_assert(memory_after - memory_before <= 0,
		"Phase 6 steady state has zero static growth (%d bytes)" % (memory_after - memory_before))
	_assert_int(sim.target_pool.bodies.size(), 32, "Target pool stays fixed-size")
	_assert_int(sim.impact_pool.markers.size(), 32, "Impact pool stays fixed-size")
	_dispose_sim(sim)

func _run_tier_5() -> void:
	print("\n--- Tier 5: Production Guardrails and 18-Suite Regression Gate ---")
	_start_test("Tier 5.1: All 25 production scripts declare class_name and stay <= 250 lines")
	var production_files: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			production_files.append(file)
	_assert(production_files.size() >= 25, "Discovered all 25 production scripts")
	for file in production_files:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		var line_count: int = text.split("\n").size()
		if text.ends_with("\n"):
			line_count -= 1
		_assert(line_count > 0 and line_count <= 250,
			"%s has %d lines (limit 250)" % [file, line_count])
		_assert(text.begins_with("class_name "), "%s declares class_name" % file)
	for required in [
		"TargetPoolManager.gd", "ImpactEffectPoolManager.gd", "ProjectilePoolManager.gd",
		"SpaceshipWeaponSystem.gd", "CockpitHUD.gd", "MobileTouchController.gd",
		"PlanetarySimulation.gd", "SimulationTelemetry.gd"
	]:
		_assert(production_files.has(required), "%s is a production script" % required)

	if OS.get_cmdline_user_args().has("--direct-regression"):
		print("  [SKIP] Nested Phase 1-5 regression gate (direct Phase 9 orchestration)")
		return
	_start_test("Tier 5.2: All 18 prior Phase 1-5 suites pass")
	var suites: Array[String] = []
	for file in DirAccess.get_files_at("res://"):
		if file.begins_with("test_") and file.ends_with(".gd") \
			and file != "test_phase6_targets_combat_mobile_headless.gd" \
			and file != "test_phase7_thermal_governor_encounters_headless.gd" \
			and file != "test_phase8_waypoints_evasion_hud_headless.gd":
			suites.append(file)
	suites.sort()
	_assert_int(suites.size(), 18, "Discovered all 18 prior headless suites")
	var executable: String = OS.get_executable_path()
	for suite in suites:
		var output: Array = []
		var exit_code: int = OS.execute(
			executable,
			PackedStringArray([
				"--headless", "-s", ProjectSettings.globalize_path("res://" + suite)
			]),
			output,
			true
		)
		_assert_int(exit_code, 0, "%s exited successfully" % suite)
		if exit_code != 0:
			printerr("    [SUITE OUTPUT] %s" % str(output))
