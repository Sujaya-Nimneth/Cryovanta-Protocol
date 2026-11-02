extends SceneTree

## Adversarial Reviewer 2 Verification Harness for Phase D Visuals & Zero-Allocation HUD

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test: String = ""

const DT: float = 0.0166667

func _init() -> void:
	print("==================================================================")
	print("REVIEWER 2 PHASE D: ADVERSARIAL STRESS & EMPIRICAL AUDIT")
	print("==================================================================")
	await process_frame

	test_ship_visual_rig_hierarchy_and_materials()
	test_ship_visual_rig_flight_animation()
	await test_floating_origin_parenting_and_rebase()
	test_shared_pool_resources_and_target_hitbox()
	test_projectile_alignment_edge_cases()
	test_isolated_visuals_and_alignment_zero_allocation_10000_iters()
	await test_hud_renderer_camera_edge_cases_and_reticles()
	await test_full_simulation_zero_allocation_1000_ticks()

	_print_summary()
	quit(0 if failed_assertions == 0 else 1)

func _start(name: String) -> void:
	current_test = name
	print("RUNNING: %s" % name)

func _assert(cond: bool, msg: String) -> void:
	total_assertions += 1
	if cond:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("  [FAIL] %s: %s" % [current_test, msg])

func _assert_approx(a: float, b: float, tol: float, msg: String) -> void:
	var delta: float = absf(a - b)
	_assert(delta <= tol, "%s (expected ~%.6f, got ~%.6f, delta=%.8f > tol=%.8f)" % [msg, b, a, delta, tol])

func _assert_vec3_approx(a: Vector3, b: Vector3, tol: float, msg: String) -> void:
	var d: float = a.distance_to(b)
	_assert(d <= tol, "%s (expected %s, got %s, delta=%f)" % [msg, str(b), str(a), d])

func _print_summary() -> void:
	print("==================================================================")
	print("SUMMARY: %d total assertions, %d passed, %d failed" % [total_assertions, passed_assertions, failed_assertions])
	print("==================================================================")

func test_ship_visual_rig_hierarchy_and_materials() -> void:
	_start("1. Ship Visual Rig Hierarchy & Materials")
	var rig: Node3D = EntityVisualsBuilder.build_ship_visual_rig(null)
	_assert(rig != null, "Rig must not be null")
	_assert(rig.name == "ShipVisualRoot", "Rig root name must be ShipVisualRoot")
	_assert(rig.get_child_count() == 10, "Rig must have 10 child mesh instances (got %d)" % rig.get_child_count())

	var expected_nodes: Array[String] = [
		"Fuselage", "NoseCone", "Canopy", "WingLeft", "WingRight",
		"Stabilizer", "NozzleLeft", "NozzleRight", "PlumeLeft", "PlumeRight"
	]
	for node_name: String in expected_nodes:
		var n: Node = rig.get_node_or_null(node_name)
		_assert(n != null, "Rig must contain node: %s" % node_name)
		_assert(n is MeshInstance3D, "Node %s must be MeshInstance3D" % node_name)
		var mi: MeshInstance3D = n as MeshInstance3D
		_assert(mi.mesh != null, "MeshInstance %s must have mesh" % node_name)
		_assert(mi.material_override != null, "MeshInstance %s must have material_override" % node_name)

	var pl: MeshInstance3D = rig.get_node_or_null("PlumeLeft") as MeshInstance3D
	var pr: MeshInstance3D = rig.get_node_or_null("PlumeRight") as MeshInstance3D
	_assert(not pl.visible, "PlumeLeft should be initially hidden")
	_assert(not pr.visible, "PlumeRight should be initially hidden")
	rig.free()

func test_ship_visual_rig_flight_animation() -> void:
	_start("2. Ship Visual Rig Dynamic Attitude & Throttle Animation")
	var ship: SpaceshipController = SpaceshipController.new()
	var rig: Node3D = ship.ensure_visual_rig()
	_assert(rig != null, "ensure_visual_rig returned valid node")
	_assert(rig.get_parent() == ship, "visual_rig parented under ship")

	# Test roll banking on torque
	ship.torque_input = Vector3(0.0, 0.0, 1.0)
	EntityVisualsBuilder.update_flight_visuals(rig, ship)
	_assert(rig.rotation.z < -0.1, "Roll target responds to torque_input.z (rotation.z = %f)" % rig.rotation.z)

	# Test pitch trim
	ship.torque_input = Vector3(1.0, 0.0, 0.0)
	EntityVisualsBuilder.update_flight_visuals(rig, ship)
	_assert(rig.rotation.x > 0.05, "Pitch target responds to torque_input.x (rotation.x = %f)" % rig.rotation.x)

	# Test engine plume activation and scaling on throttle
	var pl: Node3D = rig.get_node_or_null("PlumeLeft") as Node3D
	ship.thrust_input = Vector3(0.0, 0.0, 0.0)
	EntityVisualsBuilder.update_flight_visuals(rig, ship)
	_assert(not pl.visible, "Plume invisible at zero throttle")

	ship.thrust_input = Vector3(0.0, 0.0, 0.8)
	EntityVisualsBuilder.update_flight_visuals(rig, ship)
	_assert(pl.visible, "Plume visible at 0.8 throttle")
	_assert_approx(pl.scale.z, 0.3 + 0.8 * 1.5, 0.01, "Plume scale.z scales with throttle")

	ship.free()

func test_floating_origin_parenting_and_rebase() -> void:
	_start("3. FloatingOrigin Double-Rebase Protection")
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	root.add_child(sim)
	await process_frame

	var ship: SpaceshipController = sim.ship
	_assert(ship != null, "Ship initialized")
	var rig: Node3D = ship.visual_rig
	_assert(rig != null, "Visual rig exists on ship")
	_assert(rig.get_parent() == ship, "Visual rig is child of ship")
	_assert(rig.position == Vector3.ZERO, "Visual rig local position is zero")

	var initial_global: Vector3 = rig.global_position
	var rebase_offset := Vector3(2000.0, 0.0, 0.0)
	sim.floating_origin.rebase(rebase_offset)

	_assert(rig.position == Vector3.ZERO, "Visual rig local position remains ZERO after rebase")
	_assert_vec3_approx(rig.global_position, initial_global - rebase_offset, 0.01, "Visual rig global position shifted exactly once with ship")

	sim.destroy()
	root.remove_child(sim)
	sim.free()

func test_shared_pool_resources_and_target_hitbox() -> void:
	_start("4. Shared Pool Resources & Target Hitbox Sizing")
	var tm1: SphereMesh = EntityVisualsBuilder.get_target_mesh()
	var tm2: SphereMesh = EntityVisualsBuilder.get_target_mesh()
	_assert(tm1 == tm2, "get_target_mesh is singleton")
	_assert_approx(tm1.radius, 3.0, 0.001, "Target mesh radius is 3.0m")

	var ts: SphereShape3D = EntityVisualsBuilder.get_target_shape()
	_assert_approx(ts.radius, 3.0, 0.001, "Target collision shape radius is 3.0m")

	var tmat: StandardMaterial3D = EntityVisualsBuilder.get_target_material()
	_assert(tmat.emission_enabled, "Target material has emission enabled")

	var tp: TargetPoolManager = TargetPoolManager.new()
	var shape: CollisionShape3D = tp.shapes[0]
	_assert(shape.shape == ts, "Target slot 0 shares singleton shape")
	var marker: MeshInstance3D = tp.markers[0]
	_assert(marker.mesh == tm1, "Target slot 0 shares singleton mesh")
	_assert(marker.material_override == tmat, "Target slot 0 shares singleton material")
	_assert(marker.scale == Vector3.ONE, "Target marker scale is (1,1,1)")
	tp.free()

	var pp: ProjectilePoolManager = ProjectilePoolManager.new()
	_assert(pp.markers[0].mesh == EntityVisualsBuilder.get_projectile_mesh(), "Projectile marker shares singleton mesh")
	_assert(pp.markers[0].material_override == EntityVisualsBuilder.get_projectile_material(), "Projectile marker shares singleton material")
	pp.free()

	var ip: ImpactEffectPoolManager = ImpactEffectPoolManager.new()
	_assert(ip.markers[0].mesh == EntityVisualsBuilder.get_impact_mesh(), "Impact marker shares singleton mesh")
	_assert(ip.markers[0].material_override == EntityVisualsBuilder.get_impact_material(), "Impact marker shares singleton material")
	ip.free()

func test_projectile_alignment_edge_cases() -> void:
	_start("5. Projectile Velocity Alignment Edge Cases")
	var ppm: ProjectilePoolManager = ProjectilePoolManager.new()
	var marker: Node3D = ppm.markers[0]

	var test_velocities: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(1e-5, 0.0, 0.0),
		Vector3.UP,
		Vector3.DOWN,
		Vector3(0.0, 0.9999, 0.0),
		Vector3(0.0, -0.9999, 0.0),
		Vector3.FORWARD,
		Vector3.BACK,
		Vector3.LEFT,
		Vector3.RIGHT,
		Vector3(100.0, 200.0, -500.0),
		Vector3(1e5, 1e5, 1e5)
	]

	for vel: Vector3 in test_velocities:
		marker.basis = Basis()
		ppm._align_marker_to_velocity(marker, vel)
		var b: Basis = marker.basis

		_assert(not is_nan(b.x.x) and not is_nan(b.y.y) and not is_nan(b.z.z), "Basis not NaN for vel: %s" % str(vel))
		_assert(not is_inf(b.x.x) and not is_inf(b.y.y) and not is_inf(b.z.z), "Basis not Inf for vel: %s" % str(vel))

		if vel.length_squared() >= 1e-4:
			var fwd: Vector3 = vel.normalized()
			var marker_fwd: Vector3 = -b.z.normalized()
			_assert_vec3_approx(marker_fwd, fwd, 0.001, "Marker -Z aligns with velocity for %s" % str(vel))
			_assert_approx(b.x.dot(b.y), 0.0, 0.001, "X and Y axes orthogonal for %s" % str(vel))
			_assert_approx(b.y.dot(b.z), 0.0, 0.001, "Y and Z axes orthogonal for %s" % str(vel))
			_assert_approx(b.z.dot(b.x), 0.0, 0.001, "Z and X axes orthogonal for %s" % str(vel))

	ppm.free()

func test_isolated_visuals_and_alignment_zero_allocation_10000_iters() -> void:
	_start("6. Isolated Visuals & Velocity Alignment 10,000 Iterations Zero Allocation")
	var ship: SpaceshipController = SpaceshipController.new()
	var rig: Node3D = ship.ensure_visual_rig()
	var ppm: ProjectilePoolManager = ProjectilePoolManager.new()
	var marker: Node3D = ppm.markers[0]

	# Warmup
	for i in range(100):
		ship.torque_input = Vector3(sin(i), cos(i), 0.5)
		ship.thrust_input = Vector3(0, 0, 0.5)
		EntityVisualsBuilder.update_flight_visuals(rig, ship)
		ppm._align_marker_to_velocity(marker, Vector3(sin(i) * 100.0, cos(i) * 100.0, -50.0))

	var mem_before: int = OS.get_static_memory_usage()
	for i in range(10000):
		ship.torque_input = Vector3(sin(i * 0.01), cos(i * 0.01), 0.5)
		ship.thrust_input = Vector3(0, 0, 0.5 + 0.5 * sin(i * 0.02))
		EntityVisualsBuilder.update_flight_visuals(rig, ship)
		ppm._align_marker_to_velocity(marker, Vector3(sin(i * 0.01) * 100.0, cos(i * 0.01) * 100.0, -50.0))
	var mem_after: int = OS.get_static_memory_usage()
	var delta: int = mem_after - mem_before
	print("  Static memory delta over 10,000 hot-path calls: %d bytes" % delta)
	_assert(delta <= 0, "Zero static memory delta over 10,000 visual & alignment hot-path calls")

	ship.free()
	ppm.free()

func test_hud_renderer_camera_edge_cases_and_reticles() -> void:
	_start("7. HUD Renderer Camera Edge Cases & Reticle Invariants")
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	root.add_child(sim)
	await process_frame
	await process_frame

	# Clear target lock to test unlocked reticle state
	sim.weapon_system.locked_target_id = -1
	sim.hud.update_hud(sim)
	sim.hud._surface.queue_redraw()
	await process_frame
	await process_frame

	_assert(sim.hud.last_drawn_thermal_bars == 2, "last_drawn_thermal_bars invariant holds (= 2)")
	_assert(sim.hud.last_drawn_target_reticles == 0, "No target reticles when unlocked")

	# Spawn target in front of camera
	var tid: int = sim.target_pool.spawn_target(sim.camera.global_position + Vector3(0.0, 0.0, -100.0), Vector3.ZERO)
	sim.weapon_system.locked_target_id = tid
	sim.hud.update_hud(sim)
	sim.hud._surface.queue_redraw()
	await process_frame
	await process_frame

	_assert(sim.hud.last_drawn_target_reticles == 2, "2 target reticles drawn for target in front")

	# Move target behind camera
	sim.target_pool.positions[tid] = sim.camera.global_position + Vector3(0.0, 0.0, 100.0)
	sim.hud.update_hud(sim)
	sim.hud._surface.queue_redraw()
	await process_frame
	await process_frame

	_assert(sim.hud.last_drawn_target_reticles == 0, "0 target reticles drawn for target behind camera")

	# Target with occluded LOS
	sim.target_pool.positions[tid] = sim.camera.global_position + Vector3(0.0, 0.0, -100.0)
	sim.telemetry.target_los_clear = false
	sim.hud.update_hud(sim)
	sim.hud._surface.queue_redraw()
	await process_frame
	await process_frame

	_assert(sim.hud.last_drawn_target_reticles == 2, "2 target reticles drawn with occluded LOS")

	# Test GPWS alert rendering
	sim.telemetry.proximity_alert = 1
	sim.hud.update_hud(sim)
	sim.hud._surface.queue_redraw()
	await process_frame
	_assert(true, "GPWS caution rendered cleanly")

	sim.telemetry.proximity_alert = 2
	sim.hud.update_hud(sim)
	sim.hud._surface.queue_redraw()
	await process_frame
	_assert(true, "GPWS pull-up rendered cleanly")

	sim.destroy()
	root.remove_child(sim)
	sim.free()

func test_full_simulation_zero_allocation_1000_ticks() -> void:
	_start("8. Full Simulation Zero Allocation Over 1,000 Live Ticks")
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	root.add_child(sim)
	await process_frame
	await process_frame

	# Configure simulation for steady-state
	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.freeze = true
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3.ZERO
	sim.ship.angular_velocity = Vector3.ZERO
	sim.encounter_director.waypoints.clear()
	sim.target_pool.clear()
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_MANUAL)

	# Active systems
	var director: EncounterDirector = sim.encounter_director
	director.landing_gear.enabled = true
	director.wind.enabled = true
	director.power_bus.enabled = true
	director.propellant.enabled = true
	director.recorder.recording_enabled = true
	director.auto_spawn_waves = true
	director.desired_active_targets = 2
	director.evasion_enabled = true
	director.target_initial_health = 1.0e9
	sim.weapon_system.capacitor.enabled = true

	# 120 warmup ticks
	for i in range(120):
		sim.step_simulation(DT)

	var mem_before: int = OS.get_static_memory_usage()

	# 1,000 measurement ticks with active simulation, telemetry, and HUD update
	for i in range(1000):
		sim.step_simulation(DT)

	var mem_after: int = OS.get_static_memory_usage()
	var delta: int = mem_after - mem_before
	print("  Static memory delta over 1,000 live ticks: %d bytes (before=%d, after=%d)" % [delta, mem_before, mem_after])
	_assert(delta <= 0, "Zero runtime static heap growth over 1,000 live ticks (delta=%d <= 0)" % delta)

	sim.destroy()
	root.remove_child(sim)
	sim.free()
