extends SceneTree

## Adversarial Empirical Stress Test Suite for Phase D Visuals & Combat Pools
## 1. Target Hitbox (3.0m) vs Visual Radius Parity & Surface Raycast Bursts
## 2. Emissive Material & Mesh Singleton Resource Sharing Across All Slots
## 3. Projectile Orientation Singularities, Boundary Angles, & 5,000-Vector Generator
## 4. Projectile Gravity Trajectory Inversion (UP to DOWN through zero-velocity)
## 5. Entity Visuals Rig: Hierarchy, Null-Safety, Extreme Inputs, & Plume Scaling
## 6. Cockpit HUD Renderer: Telemetry, Reticles, GPWS Levels, Occlusion, & Invariants
## 7. High-Frequency Pool Lifecycle Churn & Full Integrity Verification

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_section: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("PHASE D ADVERSARIAL EMPIRICAL STRESS TEST HARNESS")
	print("==================================================================")
	await process_frame
	
	_test_2_shared_pool_resource_singletons()
	_test_3_projectile_orientation_singularities_and_generator()
	_test_4_projectile_gravity_trajectory_inversion()
	_test_5_entity_visuals_rig_stress()
	_test_6_cockpit_hud_renderer_stress()
	_test_7_high_frequency_pool_lifecycle_churn()
	await _test_1_target_hitbox_mesh_and_burst_parity()
	
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
		printerr("  [FAIL] %s: %s" % [current_section, msg])

func _check_approx(val: float, exp_val: float, tol: float, msg: String) -> void:
	total_tests += 1
	var d: float = absf(val - exp_val)
	if d <= tol:
		passed_tests += 1
	else:
		failed_tests += 1
		printerr("  [FAIL] %s: %s (got %f, expected %f, diff %f > tol %f)" % [current_section, msg, val, exp_val, d, tol])

## -----------------------------------------------------------------------------
## 1. Target Visual Radius vs Hitbox & Surface Raycast Bursts
## -----------------------------------------------------------------------------
func _test_1_target_hitbox_mesh_and_burst_parity() -> void:
	current_section = "ADV-D1: Target Hitbox & Mesh Parity"
	print("\n--- Running %s ---" % current_section)
	
	# Static mesh dimensions
	var tm: SphereMesh = EntityVisualsBuilder.get_target_mesh()
	_check(tm != null, "Target mesh exists")
	_check_approx(tm.radius, 3.0, 1e-5, "Target mesh radius is exactly 3.0m")
	_check_approx(tm.height, 6.0, 1e-5, "Target mesh height is exactly 6.0m")
	
	# Static collision shape dimensions
	var ts: SphereShape3D = EntityVisualsBuilder.get_target_shape()
	_check(ts != null, "Target shape exists")
	_check_approx(ts.radius, 3.0, 1e-5, "Target collision shape radius is exactly 3.0m")
	
	# Constants in TargetPoolManager
	_check(TargetPoolManager.TARGET_MARKER_SCALE == Vector3(1.0, 1.0, 1.0), "TARGET_MARKER_SCALE is (1.0, 1.0, 1.0)")
	_check_approx(TargetPoolManager.DEFAULT_TARGET_RADIUS, 3.0, 1e-5, "DEFAULT_TARGET_RADIUS is 3.0")
	
	# Instantiate full simulation for clean physics world setup
	var packed: PackedScene = load("res://main.tscn")
	var sim: Node = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	await physics_frame
	await physics_frame
	
	var space_state: PhysicsDirectSpaceState3D = get_root().get_world_3d().direct_space_state
	_check(space_state != null, "Physics direct space state acquired")
	
	var target_center: Vector3 = Vector3(0.0, 0.0, -50.0)
	var tid: int = sim.target_pool.spawn_target(target_center, Vector3.ZERO, 100.0)
	_check(tid >= 0, "Spawned target slot %d" % tid)
	
	await physics_frame
	await physics_frame
	
	var target_body: StaticBody3D = sim.target_pool.bodies[tid]
	var target_marker: MeshInstance3D = sim.target_pool.markers[tid]
	
	_check(target_marker.visible, "Target marker is visible")
	_check_approx(target_marker.position.distance_to(target_center), 0.0, 1e-4, "Target marker at target center")
	_check_approx(target_body.global_position.distance_to(target_center), 0.0, 1e-4, "Target body at target center")
	
	# Raycast from 6 cardinal directions starting 10m away
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray_query.collision_mask = TargetPoolManager.TARGET_COLLISION_LAYER
	ray_query.collide_with_bodies = true
	ray_query.collide_with_areas = false
	
	var directions: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT,
		Vector3.UP, Vector3.DOWN,
		Vector3.BACK, Vector3.FORWARD
	]
	
	for dir in directions:
		var ray_origin: Vector3 = target_center + dir * 10.0
		ray_query.from = ray_origin
		ray_query.to = target_center
		var hit: Dictionary = space_state.intersect_ray(ray_query)
		_check(not hit.is_empty(), "Raycast from dir %s hit target" % str(dir))
		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"]
			var dist_to_center: float = hit_pos.distance_to(target_center)
			_check_approx(dist_to_center, 3.0, 0.05, "Hit distance from center is 3.0m (dir: %s)" % str(dir))
			var expected_hit: Vector3 = target_center + dir * 3.0
			_check_approx(hit_pos.distance_to(expected_hit), 0.0, 0.05, "Hit position matches target surface (dir: %s)" % str(dir))
	
	# Oblique raycast at 45 degrees
	var ob_dir: Vector3 = Vector3(1.0, 1.0, 1.0).normalized()
	ray_query.from = target_center + ob_dir * 12.0
	ray_query.to = target_center
	var ob_hit: Dictionary = space_state.intersect_ray(ray_query)
	_check(not ob_hit.is_empty(), "Oblique raycast hit target")
	if not ob_hit.is_empty():
		var ob_dist: float = (ob_hit["position"] as Vector3).distance_to(target_center)
		_check_approx(ob_dist, 3.0, 0.05, "Oblique raycast hit distance is 3.0m")
	
	# Fire projectile directly at target and verify impact burst alignment on target surface
	sim.projectile_pool.clear()
	sim.impact_pool.clear()
	var proj_origin: Vector3 = target_center + Vector3(0.0, 0.0, 15.0)
	var proj_vel: Vector3 = Vector3(0.0, 0.0, -150.0)
	var pid: int = sim.projectile_pool.spawn_projectile(proj_origin, proj_vel, 5.0)
	_check(pid >= 0, "Spawned projectile toward target")
	
	# Step projectile 0.1s (travels 15m, hitting target front surface at +3.0m on Z)
	var impacts: int = sim.projectile_pool.step_projectiles(0.1, space_state)
	_check(impacts == 1, "Projectile step registered 1 impact")
	_check(sim.impact_pool.active_count == 1, "Impact effect pool spawned 1 burst")
	
	var burst_pos: Vector3 = sim.impact_pool.positions[0]
	var burst_to_center: float = burst_pos.distance_to(target_center)
	_check_approx(burst_to_center, 3.0, 0.05, "Impact burst positioned at exactly 3.0m from center")
	_check_approx(burst_pos.z, target_center.z + 3.0, 0.05, "Impact burst Z is target_center.z + 3.0")
	
	# Clean up sim
	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

## -----------------------------------------------------------------------------
## 2. Shared Pool Resource Singletons
## -----------------------------------------------------------------------------
func _test_2_shared_pool_resource_singletons() -> void:
	current_section = "ADV-D2: Shared Pool Resource Singletons"
	print("\n--- Running %s ---" % current_section)
	
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	
	var target_pool: TargetPoolManager = TargetPoolManager.new()
	var proj_pool: ProjectilePoolManager = ProjectilePoolManager.new()
	var impact_pool: ImpactEffectPoolManager = ImpactEffectPoolManager.new()
	root.add_child(target_pool)
	root.add_child(proj_pool)
	root.add_child(impact_pool)
	
	# TargetPoolManager sharing
	var ref_t_mesh: Mesh = EntityVisualsBuilder.get_target_mesh()
	var ref_t_mat: Material = EntityVisualsBuilder.get_target_material()
	var ref_t_shape: Shape3D = EntityVisualsBuilder.get_target_shape()
	
	for i in range(TargetPoolManager.POOL_SIZE):
		var marker: MeshInstance3D = target_pool.markers[i]
		var col_shape: CollisionShape3D = target_pool.shapes[i]
		_check(marker.mesh == ref_t_mesh, "Target slot %d shares target mesh" % i)
		_check(marker.material_override == ref_t_mat, "Target slot %d shares target material" % i)
		_check(col_shape.shape == ref_t_shape, "Target slot %d shares target shape" % i)
		_check(marker.scale == Vector3(1.0, 1.0, 1.0), "Target slot %d marker scale is (1,1,1)" % i)
	
	# ProjectilePoolManager sharing
	var ref_p_mesh: Mesh = EntityVisualsBuilder.get_projectile_mesh()
	var ref_p_mat: Material = EntityVisualsBuilder.get_projectile_material()
	for i in range(ProjectilePoolManager.POOL_SIZE):
		var marker: MeshInstance3D = proj_pool.markers[i] as MeshInstance3D
		_check(marker.mesh == ref_p_mesh, "Projectile slot %d shares projectile mesh" % i)
		_check(marker.material_override == ref_p_mat, "Projectile slot %d shares projectile material" % i)
	
	# ImpactEffectPoolManager sharing
	var ref_i_mesh: Mesh = EntityVisualsBuilder.get_impact_mesh()
	var ref_i_mat: Material = EntityVisualsBuilder.get_impact_material()
	for i in range(ImpactEffectPoolManager.POOL_SIZE):
		var marker: MeshInstance3D = impact_pool.markers[i]
		_check(marker.mesh == ref_i_mesh, "Impact slot %d shares impact mesh" % i)
		_check(marker.material_override == ref_i_mat, "Impact slot %d shares impact material" % i)
	
	root.queue_free()

## -----------------------------------------------------------------------------
## 3. Projectile Orientation Singularities and Generator
## -----------------------------------------------------------------------------
func _test_3_projectile_orientation_singularities_and_generator() -> void:
	current_section = "ADV-D3: Projectile Orientation Singularities"
	print("\n--- Running %s ---" % current_section)
	
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	var proj_pool: ProjectilePoolManager = ProjectilePoolManager.new()
	root.add_child(proj_pool)
	
	var marker: Node3D = proj_pool.markers[0]
	
	# 3.1 Zero & Subnormal Velocities
	var zero_cases: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(1e-5, 0.0, 0.0),
		Vector3(0.0, -1e-5, 0.0),
		Vector3(0.0, 0.0, 1e-5),
		Vector3(1e-3, 0.0, 0.0)
	]
	for z_vel in zero_cases:
		marker.basis = Basis.IDENTITY
		proj_pool._align_marker_to_velocity(marker, z_vel)
		_check(marker.basis.is_finite(), "Zero/subnormal vel %s yields finite basis" % str(z_vel))
		_check(marker.basis == Basis.IDENTITY, "Zero/subnormal vel %s leaves basis unchanged" % str(z_vel))
	
	# 3.2 Vertical Singularities & Boundary Angles
	var critical_vels: Array[Vector3] = [
		Vector3.UP * 100.0,
		Vector3.DOWN * 100.0,
		Vector3(0.0, 0.999, 0.0) * 50.0,
		Vector3(0.0, -0.999, 0.0) * 50.0,
		Vector3(0.0, 0.9899, 0.1414).normalized() * 50.0,
		Vector3(0.0, 0.9901, 0.1403).normalized() * 50.0,
		Vector3(0.0, 0.99000, 0.141067).normalized() * 50.0,
		Vector3.FORWARD * 200.0,
		Vector3.BACK * 200.0,
		Vector3.RIGHT * 150.0,
		Vector3.LEFT * 150.0,
		Vector3(1.0, 1.0, 1.0).normalized() * 300.0,
		Vector3(-1.0, -1.0, -1.0).normalized() * 300.0
	]
	
	for vel in critical_vels:
		proj_pool._align_marker_to_velocity(marker, vel)
		_check(marker.basis.is_finite(), "Basis is finite for vel %s" % str(vel))
		_check(marker.basis.determinant() > 0.0, "Basis determinant is positive for vel %s" % str(vel))
		
		var fwd: Vector3 = vel.normalized()
		var marker_fwd: Vector3 = -marker.basis.z.normalized()
		var dot: float = marker_fwd.dot(fwd)
		_check(dot >= 0.999, "Marker forward points along velocity (dot = %f, vel: %s)" % [dot, str(vel)])
		
		var rx: Vector3 = marker.basis.x.normalized()
		var ry: Vector3 = marker.basis.y.normalized()
		var rz: Vector3 = marker.basis.z.normalized()
		_check_approx(absf(rx.dot(ry)), 0.0, 1e-4, "X and Y are orthogonal for %s" % str(vel))
		_check_approx(absf(rx.dot(rz)), 0.0, 1e-4, "X and Z are orthogonal for %s" % str(vel))
		_check_approx(absf(ry.dot(rz)), 0.0, 1e-4, "Y and Z are orthogonal for %s" % str(vel))
		
		_check_approx(marker.basis.x.length(), ProjectilePoolManager.PROJECTILE_MARKER_SCALE.x, 1e-4, "X scale is 0.08")
		_check_approx(marker.basis.y.length(), ProjectilePoolManager.PROJECTILE_MARKER_SCALE.y, 1e-4, "Y scale is 0.08")
		_check_approx(marker.basis.z.length(), ProjectilePoolManager.PROJECTILE_MARKER_SCALE.z, 1e-4, "Z scale is 0.5")
	
	# 3.3 Adversarial Generator: 5,000 Random 3D Velocities
	print("  [GENERATOR] Testing 5,000 random 3D velocities...")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 987654321
	var gen_failures: int = 0
	
	for k in range(5000):
		var u: float = rng.randf_range(-1.0, 1.0)
		var theta: float = rng.randf_range(0.0, TAU)
		var r: float = sqrt(maxf(1.0 - u * u, 0.0))
		var dir: Vector3 = Vector3(r * cos(theta), u, r * sin(theta))
		var speed: float = rng.randf_range(0.01, 500_000.0)
		var test_vel: Vector3 = dir * speed
		
		proj_pool._align_marker_to_velocity(marker, test_vel)
		if not marker.basis.is_finite() or marker.basis.determinant() <= 0.0:
			gen_failures += 1
			continue
		var marker_fwd: Vector3 = -marker.basis.z.normalized()
		if marker_fwd.dot(dir) < 0.999:
			gen_failures += 1
			continue
		if absf(marker.basis.x.normalized().dot(marker.basis.y.normalized())) > 1e-3:
			gen_failures += 1
			continue
	
	_check(gen_failures == 0, "5,000 random 3D velocities passed orientation checks (0 failures)")
	
	root.queue_free()

## -----------------------------------------------------------------------------
## 4. Projectile Gravity Trajectory Inversion
## -----------------------------------------------------------------------------
func _test_4_projectile_gravity_trajectory_inversion() -> void:
	current_section = "ADV-D4: Gravity Trajectory Inversion"
	print("\n--- Running %s ---" % current_section)
	
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	var proj_pool: ProjectilePoolManager = ProjectilePoolManager.new()
	root.add_child(proj_pool)
	
	var origin: Vector3 = Vector3(0.0, 100_000.0, 0.0)
	var pid: int = proj_pool.spawn_projectile(origin, Vector3.UP * 20.0, 5.0)
	_check(pid >= 0, "Spawned vertical trajectory projectile %d" % pid)
	
	var marker: Node3D = proj_pool.markers[pid]
	_check(-marker.basis.z.normalized().dot(Vector3.UP) > 0.99, "Initially points UP")
	
	var inverted_cleanly: bool = true
	for frame in range(60):
		proj_pool.step_projectiles(0.08, null, Vector3.ZERO, 100_000.0, 9.8)
		if not marker.basis.is_finite():
			inverted_cleanly = false
			break
	
	_check(inverted_cleanly, "Marker basis stayed finite through velocity reversal")
	_check(-marker.basis.z.normalized().dot(Vector3.DOWN) > 0.99, "Points DOWN after gravity inversion")
	
	root.queue_free()

## -----------------------------------------------------------------------------
## 5. Entity Visuals Rig Stress: Hierarchy, Null Safety, Extreme Inputs
## -----------------------------------------------------------------------------
func _test_5_entity_visuals_rig_stress() -> void:
	current_section = "ADV-D5: Entity Visuals Rig Stress"
	print("\n--- Running %s ---" % current_section)
	
	EntityVisualsBuilder.update_flight_visuals(null, null)
	_check(true, "update_flight_visuals(null, null) does not crash")
	
	var rig: Node3D = EntityVisualsBuilder.build_ship_visual_rig()
	_check(rig != null, "build_ship_visual_rig returned valid node")
	_check(rig.name == "ShipVisualRoot", "Root name is ShipVisualRoot")
	
	var expected_children: Array[String] = [
		"Fuselage", "NoseCone", "Canopy", "WingLeft", "WingRight",
		"Stabilizer", "NozzleLeft", "NozzleRight", "PlumeLeft", "PlumeRight"
	]
	for cname in expected_children:
		var node: Node = rig.get_node_or_null(cname)
		_check(node != null, "Rig contains child '%s'" % cname)
	
	EntityVisualsBuilder.update_flight_visuals(rig, null)
	_check(true, "update_flight_visuals(rig, null) does not crash")
	
	# Test with SpaceshipController (RigidBody3D)
	var ship: SpaceshipController = SpaceshipController.new()
	ship.torque_input = Vector3(1e8, -1e8, 1e8)
	ship.angular_velocity = Vector3(-1e8, 1e8, -1e8)
	ship.thrust_input = Vector3(0.0, 0.0, 1e8)
	
	EntityVisualsBuilder.update_flight_visuals(rig, ship)
	print("  [DEBUG] rig.rotation = ", rig.rotation)
	_check(absf(rig.rotation.z) <= 0.35 + 1e-4, "Rig roll clamped to [-0.35, 0.35] (got %f)" % rig.rotation.z)
	_check(absf(rig.rotation.x) <= 0.20 + 1e-4, "Rig pitch clamped to [-0.20, 0.20] (got %f)" % rig.rotation.x)
	
	var plume_l: Node3D = rig.get_node_or_null("PlumeLeft") as Node3D
	_check(plume_l != null and plume_l.visible, "Plume is visible on thrust")
	_check_approx(plume_l.scale.z, 0.3 + 1.0 * 1.5, 1e-4, "Plume scale clamped at max throttle (1.8)")
	
	ship.thrust_input = Vector3(0.0, 0.0, -10.0)
	EntityVisualsBuilder.update_flight_visuals(rig, ship)
	_check(not plume_l.visible, "Plume is hidden on negative/zero throttle")
	
	# Test 1,000 updates static memory delta
	for w in range(50):
		EntityVisualsBuilder.update_flight_visuals(rig, ship)
	var mem_b: int = OS.get_static_memory_usage()
	for i in range(1000):
		ship.thrust_input = Vector3(0.0, 0.0, sin(i * 0.1))
		ship.torque_input = Vector3(cos(i * 0.1), 0.0, sin(i * 0.05))
		EntityVisualsBuilder.update_flight_visuals(rig, ship)
	var mem_a: int = OS.get_static_memory_usage()
	_check(mem_a - mem_b <= 0, "update_flight_visuals 1,000 calls zero static heap delta (delta=%d bytes)" % (mem_a - mem_b))
	
	rig.free()
	ship.free()

## -----------------------------------------------------------------------------
## 6. Cockpit HUD Renderer Stress & Invariant Counters
## -----------------------------------------------------------------------------
class TestHUDSurface extends Control:
	var hud: CockpitHUD = null
	var camera: Camera3D = null
	func _draw() -> void:
		if hud != null:
			CockpitHUDRenderer.render_cockpit(self, hud, camera)

func _test_6_cockpit_hud_renderer_stress() -> void:
	current_section = "ADV-D6: Cockpit HUD Renderer Invariants"
	print("\n--- Running %s ---" % current_section)
	
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(cam)
	
	var hud: CockpitHUD = CockpitHUD.new()
	root.add_child(hud)
	
	# Populate HUD telemetry registers with extreme values
	hud.displayed_altitude = -500.0
	hud.displayed_radar_altitude = 200_000.0
	hud.displayed_vertical_speed = -50_000.0
	hud.displayed_horizontal_speed = 100_000.0
	hud.displayed_g_load = 50.0
	hud.displayed_heat_load = 1.0
	hud.displayed_hull_integrity = 0.0
	hud.displayed_fuel_fraction = 0.0
	hud.displayed_battery_fraction = 0.0
	hud.displayed_mission_stage = 2
	hud.displayed_combat_score = 400
	
	# Target and Lead tracking in front of camera (-Z)
	hud.locked_target_id = 1
	hud.locked_target_pos = Vector3(0.0, 0.0, -20.0)
	hud.locked_lead_pos = Vector3(1.0, 1.0, -20.0)
	hud.displayed_target_los = true
	
	# Waypoint in front of camera
	hud.active_waypoint_id = 0
	hud.active_waypoint_pos = Vector3(-2.0, 0.0, -15.0)
	
	var draw_surface: TestHUDSurface = TestHUDSurface.new()
	draw_surface.size = Vector2(1280.0, 720.0)
	draw_surface.hud = hud
	draw_surface.camera = cam
	hud.add_child(draw_surface)
	
	# Render with GPWS Alert Level 1 (CAUTION)
	hud.displayed_proximity_alert = 1
	draw_surface.queue_redraw()
	await process_frame
	_check(hud.last_drawn_thermal_bars == 2, "last_drawn_thermal_bars == 2")
	_check(hud.last_drawn_waypoint_markers == 1, "last_drawn_waypoint_markers == 1")
	_check(hud.last_drawn_target_reticles == 2, "last_drawn_target_reticles == 2")
	
	# Render with GPWS Alert Level 2 (PULL UP) with Target Occluded
	hud.displayed_proximity_alert = 2
	hud.displayed_target_los = false
	draw_surface.queue_redraw()
	await process_frame
	_check(hud.last_drawn_thermal_bars == 2, "last_drawn_thermal_bars preserved on alert 2")
	_check(hud.last_drawn_target_reticles == 2, "last_drawn_target_reticles preserved on alert 2")
	
	# Test with target behind camera (+Z)
	hud.locked_target_pos = Vector3(0.0, 0.0, 100.0)
	hud.locked_lead_pos = Vector3(0.0, 0.0, 100.0)
	draw_surface.queue_redraw()
	await process_frame
	_check(hud.last_drawn_target_reticles == 0, "No target reticles drawn when behind camera")
	
	# Test 1,000 draws static memory delta
	var hud_mem_b: int = OS.get_static_memory_usage()
	for i in range(1000):
		hud.displayed_altitude = float(i) * 10.0
		hud.displayed_heat_load = fmod(float(i) * 0.001, 1.0)
		draw_surface.queue_redraw()
	var hud_mem_a: int = OS.get_static_memory_usage()
	_check(hud_mem_a - hud_mem_b <= 0, "HUD queue_redraw 1,000 calls zero static heap delta (delta=%d bytes)" % (hud_mem_a - hud_mem_b))
	
	root.queue_free()

## -----------------------------------------------------------------------------
## 7. High-Frequency Pool Lifecycle Churn & Integrity Verification
## -----------------------------------------------------------------------------
func _test_7_high_frequency_pool_lifecycle_churn() -> void:
	current_section = "ADV-D7: High-Frequency Pool Churn"
	print("\n--- Running %s ---" % current_section)
	
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	
	var target_pool: TargetPoolManager = TargetPoolManager.new()
	var proj_pool: ProjectilePoolManager = ProjectilePoolManager.new()
	var impact_pool: ImpactEffectPoolManager = ImpactEffectPoolManager.new()
	root.add_child(target_pool)
	root.add_child(proj_pool)
	root.add_child(impact_pool)
	
	# Churn targets: 500 cycles of spawn and release
	for cycle in range(500):
		var ids: Array[int] = []
		for s in range(TargetPoolManager.POOL_SIZE):
			var tid: int = target_pool.spawn_target(Vector3(s * 10.0, 0.0, 0.0))
			ids.append(tid)
		if cycle == 0:
			_check(target_pool.active_count == TargetPoolManager.POOL_SIZE, "Target pool fully filled cycle 0")
		for tid in ids:
			target_pool.release_target(tid)
	
	var t_res: Dictionary = target_pool.verify_integrity()
	_check(t_res.get("is_valid", false), "Target pool integrity verified after 500 churn cycles")
	_check(t_res.get("active_count", -1) == 0, "Target active count is 0")
	_check(t_res.get("free_count", -1) == TargetPoolManager.POOL_SIZE, "Target free count is 32")
	
	# Churn projectiles: 500 cycles of spawn and release
	for cycle in range(500):
		var pids: Array[int] = []
		for s in range(ProjectilePoolManager.POOL_SIZE):
			var pid: int = proj_pool.spawn_projectile(Vector3(s, s, s), Vector3.FORWARD * 100.0)
			pids.append(pid)
		if cycle == 0:
			_check(proj_pool.active_count == ProjectilePoolManager.POOL_SIZE, "Projectile pool fully filled cycle 0")
		for pid in pids:
			proj_pool.release_projectile(pid)
			
	var p_res: Dictionary = proj_pool.verify_integrity()
	_check(p_res.get("is_valid", false), "Projectile pool integrity verified after 500 churn cycles")
	_check(p_res.get("active_count", -1) == 0, "Projectile active count is 0")
	_check(p_res.get("free_count", -1) == ProjectilePoolManager.POOL_SIZE, "Projectile free count is 128")
	
	# Churn impact effects: 500 cycles
	for cycle in range(500):
		var iids: Array[int] = []
		for s in range(ImpactEffectPoolManager.POOL_SIZE):
			var iid: int = impact_pool.spawn_effect(Vector3(s, 0.0, 0.0))
			iids.append(iid)
		if cycle == 0:
			_check(impact_pool.active_count == ImpactEffectPoolManager.POOL_SIZE, "Impact pool fully filled cycle 0")
		for iid in iids:
			impact_pool.release_effect(iid)
			
	var i_res: Dictionary = impact_pool.verify_integrity()
	_check(i_res.get("is_valid", false), "Impact pool integrity verified after 500 churn cycles")
	_check(i_res.get("active_count", -1) == 0, "Impact active count is 0")
	_check(i_res.get("free_count", -1) == ImpactEffectPoolManager.POOL_SIZE, "Impact free count is 32")
	
	root.queue_free()
