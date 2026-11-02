extends SceneTree

## Adversarial empirical challenger stress test for Phase E / Phase 15.
## Rigorously stresses terrain seam continuity across all 12 edges and 8 corners,
## Vulkan compute storage buffer layout and mesh array slots,
## entity visual rigs and shared pool resources,
## and zero static memory growth under extended live simulation.

const PLANET_RADIUS: float = 100_000.0
const DT: float = 1.0 / 120.0

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var current_test_name: String = ""

func _initialize() -> void:
	_run_all.call_deferred()

func _run_all() -> void:
	print("==================================================================")
	print("Cryovanta Protocol: Empirical Challenger Phase E Stress Suite")
	print("==================================================================")
	await process_frame
	_test_seam_and_corner_continuity()
	_test_compute_dispatcher_and_array_mapping()
	_test_entity_visuals_and_pool_sharing()
	_test_touch_keyboard_coexistence_stress()
	await _test_extended_static_memory_gate()
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
	print("CHALLENGER STRESS SUITE SUMMARY")
	print("==================================================================")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	print("==================================================================")
	if failed_assertions == 0:
		print("SUCCESS: All %d challenger stress assertions passed with exit code 0!" % total_assertions)
	else:
		printerr("FAILURE: %d out of %d assertions failed!" % [failed_assertions, total_assertions])

## 1. High-Density Seam & Corner Continuity Verification
func _test_seam_and_corner_continuity() -> void:
	print("\n--- Stress 1: Planetary Terrain Seam & 8-Corner Continuity ---")
	_start_test("Stress 1.1: High-density 100-sample resolution on all 12 cube face shared edges")
	TerrainMeshBuilder.init_builder()

	var edges: Array = [
		{"fA": 0, "uvA": func(t: float) -> Vector2: return Vector2(1.0, t), "fB": 5, "uvB": func(t: float) -> Vector2: return Vector2(-1.0, t), "name": "+X Right <-> -Z Left"},
		{"fA": 0, "uvA": func(t: float) -> Vector2: return Vector2(-1.0, t), "fB": 4, "uvB": func(t: float) -> Vector2: return Vector2(1.0, t), "name": "+X Left <-> +Z Right"},
		{"fA": 0, "uvA": func(t: float) -> Vector2: return Vector2(t, 1.0), "fB": 2, "uvB": func(t: float) -> Vector2: return Vector2(-t, 1.0), "name": "+X Top <-> +Y Top"},
		{"fA": 0, "uvA": func(t: float) -> Vector2: return Vector2(t, -1.0), "fB": 3, "uvB": func(t: float) -> Vector2: return Vector2(t, 1.0), "name": "+X Bottom <-> -Y Top"},
		{"fA": 1, "uvA": func(t: float) -> Vector2: return Vector2(1.0, t), "fB": 4, "uvB": func(t: float) -> Vector2: return Vector2(-1.0, t), "name": "-X Right <-> +Z Left"},
		{"fA": 1, "uvA": func(t: float) -> Vector2: return Vector2(-1.0, t), "fB": 5, "uvB": func(t: float) -> Vector2: return Vector2(1.0, t), "name": "-X Left <-> -Z Right"},
		{"fA": 1, "uvA": func(t: float) -> Vector2: return Vector2(t, 1.0), "fB": 2, "uvB": func(t: float) -> Vector2: return Vector2(t, -1.0), "name": "-X Top <-> +Y Bottom"},
		{"fA": 1, "uvA": func(t: float) -> Vector2: return Vector2(t, -1.0), "fB": 3, "uvB": func(t: float) -> Vector2: return Vector2(-t, -1.0), "name": "-X Bottom <-> -Y Bottom"},
		{"fA": 2, "uvA": func(t: float) -> Vector2: return Vector2(-1.0, t), "fB": 5, "uvB": func(t: float) -> Vector2: return Vector2(-t, 1.0), "name": "+Y Left <-> -Z Top"},
		{"fA": 2, "uvA": func(t: float) -> Vector2: return Vector2(1.0, t), "fB": 4, "uvB": func(t: float) -> Vector2: return Vector2(t, 1.0), "name": "+Y Right <-> +Z Top"},
		{"fA": 3, "uvA": func(t: float) -> Vector2: return Vector2(1.0, t), "fB": 5, "uvB": func(t: float) -> Vector2: return Vector2(-t, -1.0), "name": "-Y Left <-> -Z Bottom"},
		{"fA": 3, "uvA": func(t: float) -> Vector2: return Vector2(-1.0, t), "fB": 4, "uvB": func(t: float) -> Vector2: return Vector2(t, -1.0), "name": "-Y Right <-> +Z Bottom"}
	]

	var test_seeds: Array[int] = [0, 42, 1337, 987654]
	var max_edge_delta: float = 0.0

	for s_seed in test_seeds:
		for edge in edges:
			var fA: int = edge["fA"]
			var fB: int = edge["fB"]
			var uvA_fn: Callable = edge["uvA"]
			var uvB_fn: Callable = edge["uvB"]
			var edge_name: String = edge["name"]

			for s in range(101):
				var t: float = -1.0 + 2.0 * float(s) / 100.0
				var uvA: Vector2 = uvA_fn.call(t)
				var uvB: Vector2 = uvB_fn.call(t)

				var dirA: Vector3 = PlanetMath.face_uv_to_sphere_dir(fA, uvA)
				var dirB: Vector3 = PlanetMath.face_uv_to_sphere_dir(fB, uvB)
				_assert(dirA.distance_to(dirB) < 1e-5, "%s [seed=%d, t=%.2f]: Sphere dir continuity" % [edge_name, s_seed, t])

				var hA: float = PlanetMath.get_terrain_height(dirA, PLANET_RADIUS, s_seed, 64.0, 500.0)
				var hB: float = PlanetMath.get_terrain_height(dirB, PLANET_RADIUS, s_seed, 64.0, 500.0)
				var delta: float = absf(hA - hB)
				if delta > max_edge_delta:
					max_edge_delta = delta
				_assert(delta < 1e-6, "%s [seed=%d, t=%.2f]: Elevation delta == 0.000000 m (delta=%.8f)" % [edge_name, s_seed, t, delta])

	print("    Max edge elevation delta across all 12 edges & 4 seeds: %.8f m" % max_edge_delta)

	_start_test("Stress 1.2: Tri-face convergence at all 8 cube corners")
	# At each corner, 3 cube faces meet.
	# Corners: (X, Y, Z) signs
	var corners: Array = [
		{"name": "Corner (+X, +Y, +Z)", "faces": [
			{"face": 0, "uv": Vector2(-1.0, 1.0)},
			{"face": 2, "uv": Vector2(1.0, 1.0)},
			{"face": 4, "uv": Vector2(1.0, 1.0)}
		]},
		{"name": "Corner (+X, +Y, -Z)", "faces": [
			{"face": 0, "uv": Vector2(1.0, 1.0)},
			{"face": 2, "uv": Vector2(-1.0, 1.0)},
			{"face": 5, "uv": Vector2(-1.0, 1.0)}
		]},
		{"name": "Corner (+X, -Y, +Z)", "faces": [
			{"face": 0, "uv": Vector2(-1.0, -1.0)},
			{"face": 3, "uv": Vector2(-1.0, 1.0)},
			{"face": 4, "uv": Vector2(1.0, -1.0)}
		]},
		{"name": "Corner (+X, -Y, -Z)", "faces": [
			{"face": 0, "uv": Vector2(1.0, -1.0)},
			{"face": 3, "uv": Vector2(1.0, 1.0)},
			{"face": 5, "uv": Vector2(-1.0, -1.0)}
		]},
		{"name": "Corner (-X, +Y, +Z)", "faces": [
			{"face": 1, "uv": Vector2(1.0, 1.0)},
			{"face": 2, "uv": Vector2(1.0, -1.0)},
			{"face": 4, "uv": Vector2(-1.0, 1.0)}
		]},
		{"name": "Corner (-X, +Y, -Z)", "faces": [
			{"face": 1, "uv": Vector2(-1.0, 1.0)},
			{"face": 2, "uv": Vector2(-1.0, -1.0)},
			{"face": 5, "uv": Vector2(1.0, 1.0)}
		]},
		{"name": "Corner (-X, -Y, +Z)", "faces": [
			{"face": 1, "uv": Vector2(1.0, -1.0)},
			{"face": 3, "uv": Vector2(-1.0, -1.0)},
			{"face": 4, "uv": Vector2(-1.0, -1.0)}
		]},
		{"name": "Corner (-X, -Y, -Z)", "faces": [
			{"face": 1, "uv": Vector2(-1.0, -1.0)},
			{"face": 3, "uv": Vector2(1.0, -1.0)},
			{"face": 5, "uv": Vector2(1.0, -1.0)}
		]}
	]

	for c in corners:
		var c_name: String = c["name"]
		var c_faces: Array = c["faces"]
		var d0: Vector3 = PlanetMath.face_uv_to_sphere_dir(c_faces[0]["face"], c_faces[0]["uv"])
		var d1: Vector3 = PlanetMath.face_uv_to_sphere_dir(c_faces[1]["face"], c_faces[1]["uv"])
		var d2: Vector3 = PlanetMath.face_uv_to_sphere_dir(c_faces[2]["face"], c_faces[2]["uv"])

		_assert(d0.distance_to(d1) < 1e-5, "%s: Dir Face %d <-> Face %d match" % [c_name, c_faces[0]["face"], c_faces[1]["face"]])
		_assert(d1.distance_to(d2) < 1e-5, "%s: Dir Face %d <-> Face %d match" % [c_name, c_faces[1]["face"], c_faces[2]["face"]])

		var h0: float = PlanetMath.get_terrain_height(d0, PLANET_RADIUS, 1337, 64.0, 500.0)
		var h1: float = PlanetMath.get_terrain_height(d1, PLANET_RADIUS, 1337, 64.0, 500.0)
		var h2: float = PlanetMath.get_terrain_height(d2, PLANET_RADIUS, 1337, 64.0, 500.0)

		_assert(absf(h0 - h1) < 1e-6, "%s: Height delta Face %d <-> %d == 0.000000 m (delta=%.8f)" % [c_name, c_faces[0]["face"], c_faces[1]["face"], absf(h0 - h1)])
		_assert(absf(h1 - h2) < 1e-6, "%s: Height delta Face %d <-> %d == 0.000000 m (delta=%.8f)" % [c_name, c_faces[1]["face"], c_faces[2]["face"], absf(h1 - h2)])

## 2. Compute Dispatcher & Array Mapping Verification
func _test_compute_dispatcher_and_array_mapping() -> void:
	print("\n--- Stress 2: Compute Dispatcher & Vulkan Buffer Layout ---")
	_start_test("Stress 2.1: std430 byte stride, alignment, and roundtrip pack/unpack")
	var dispatcher: ComputeChunkDispatcher = ComputeChunkDispatcher.new(true)
	_assert_int(ComputeChunkDispatcher.VERTEX_STRIDE_BYTES, 32, "Vertex stride is 32 bytes (vec4 + vec4)")
	_assert_int(ComputeChunkDispatcher.STORAGE_BUFFER_SIZE_BYTES, 1156 * 32, "Storage buffer size is 36992 bytes")

	# Populate raw bytes and unpack
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(ComputeChunkDispatcher.STORAGE_BUFFER_SIZE_BYTES)
	for i in range(ComputeChunkDispatcher.VERTEX_COUNT):
		var base: int = i * 32
		raw.encode_float(base, float(i) * 1.5)
		raw.encode_float(base + 4, float(i) * 2.5)
		raw.encode_float(base + 8, float(i) * 3.5)
		raw.encode_float(base + 12, 0.25)
		raw.encode_float(base + 16, 0.0)
		raw.encode_float(base + 20, 1.0)
		raw.encode_float(base + 24, 0.0)
		raw.encode_float(base + 28, 0.75)

	var unpack_ok: bool = dispatcher.unpack_std430_vertex_buffer(raw, 0)
	_assert(unpack_ok, "unpack_std430_vertex_buffer succeeded")
	_assert_vec3(Vector3(dispatcher.last_vertices[10].x, dispatcher.last_vertices[10].y, dispatcher.last_vertices[10].z), Vector3(15.0, 25.0, 35.0), 1e-4, "Unpacked vertex 10 coordinates match")
	_assert_approx(dispatcher.last_vertices[10].w, 0.25, 1e-4, "Unpacked vertex 10 uv.x matches")
	_assert_vec3(Vector3(dispatcher.last_normals[10].x, dispatcher.last_normals[10].y, dispatcher.last_normals[10].z), Vector3(0.0, 1.0, 0.0), 1e-4, "Unpacked normal 10 coordinates match")
	_assert_approx(dispatcher.last_normals[10].w, 0.75, 1e-4, "Unpacked normal 10 uv.y matches")

	_start_test("Stress 2.2: Mesh.ARRAY_MAX sizing and surface array slot positions")
	var target_mesh: ArrayMesh = ArrayMesh.new()
	dispatcher._upload_vertex_buffer_to_mesh(target_mesh)
	_assert_int(target_mesh.get_surface_count(), 1, "Surface uploaded to target_mesh")
	var arrays: Array = target_mesh.surface_get_arrays(0)
	_assert_int(arrays.size(), Mesh.ARRAY_MAX, "surface_get_arrays size is Mesh.ARRAY_MAX (%d)" % Mesh.ARRAY_MAX)

	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	_assert_int(v.size(), 1156, "Vertex array size == 1156")
	_assert_int(n.size(), 1156, "Normal array size == 1156")
	_assert_int(uv.size(), 1156, "UV array size == 1156")
	_assert_int(idx.size(), TerrainMeshBuilder.INDEX_COUNT, "Index array size == 6534")

	# Verify pre-upload _gpu_mesh_arrays mapping in dispatcher
	_assert_int(dispatcher._gpu_mesh_arrays.size(), Mesh.ARRAY_MAX, "_gpu_mesh_arrays sized to Mesh.ARRAY_MAX")
	_assert(dispatcher._gpu_mesh_arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array, "_gpu_mesh_arrays[0] is PackedVector3Array")
	_assert(dispatcher._gpu_mesh_arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array, "_gpu_mesh_arrays[1] is PackedVector3Array")
	_assert(dispatcher._gpu_mesh_arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array, "_gpu_mesh_arrays[4] is PackedVector2Array")
	_assert(dispatcher._gpu_mesh_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array, "_gpu_mesh_arrays[12] is PackedInt32Array")
	_assert(dispatcher._gpu_mesh_arrays[Mesh.ARRAY_TANGENT] == null, "_gpu_mesh_arrays[2] (ARRAY_TANGENT) is null before upload")
	_assert(dispatcher._gpu_mesh_arrays[Mesh.ARRAY_COLOR] == null, "_gpu_mesh_arrays[3] (ARRAY_COLOR) is null before upload")
	_assert(dispatcher._gpu_mesh_arrays[Mesh.ARRAY_BONES] == null, "_gpu_mesh_arrays[Mesh.ARRAY_BONES] is null before upload")

	dispatcher.shutdown()

## 3. Entity Visuals & Pool Sharing Stress
func _test_entity_visuals_and_pool_sharing() -> void:
	print("\n--- Stress 3: Entity Visuals & Pool Sharing ---")
	_start_test("Stress 3.1: Procedural ship rig hierarchy and transforms")
	var ship: SpaceshipController = SpaceshipController.new()
	var rig: Node3D = EntityVisualsBuilder.build_ship_visual_rig()
	ship.add_child(rig)
	_assert(rig != null, "Ship visual rig instantiated")

	var fuselage: MeshInstance3D = rig.get_node_or_null("Fuselage")
	var nose: MeshInstance3D = rig.get_node_or_null("NoseCone")
	var canopy: MeshInstance3D = rig.get_node_or_null("Canopy")
	var left_wing: MeshInstance3D = rig.get_node_or_null("WingLeft")
	var right_wing: MeshInstance3D = rig.get_node_or_null("WingRight")
	var stabilizer: MeshInstance3D = rig.get_node_or_null("Stabilizer")
	var nozzle_l: MeshInstance3D = rig.get_node_or_null("NozzleLeft")
	var nozzle_r: MeshInstance3D = rig.get_node_or_null("NozzleRight")
	var plume_l: MeshInstance3D = rig.get_node_or_null("PlumeLeft")
	var plume_r: MeshInstance3D = rig.get_node_or_null("PlumeRight")

	_assert(fuselage != null, "Fuselage mesh present")
	_assert(nose != null, "NoseCone mesh present")
	_assert(canopy != null, "Canopy mesh present")
	_assert(left_wing != null, "WingLeft mesh present")
	_assert(right_wing != null, "WingRight mesh present")
	_assert(stabilizer != null, "Stabilizer mesh present")
	_assert(nozzle_l != null, "NozzleLeft mesh present")
	_assert(nozzle_r != null, "NozzleRight mesh present")
	_assert(plume_l != null, "PlumeLeft mesh present")
	_assert(plume_r != null, "PlumeRight mesh present")

	# Test flight visuals update with thrust
	ship.thrust_input = Vector3(0.0, 0.0, 1.0)
	EntityVisualsBuilder.update_flight_visuals(rig, ship)
	_assert(plume_l.visible == true, "Left thruster plume visible under forward thrust")
	_assert(plume_r.visible == true, "Right thruster plume visible under forward thrust")

	# Test flight visuals update with zero thrust
	ship.thrust_input = Vector3.ZERO
	EntityVisualsBuilder.update_flight_visuals(rig, ship)
	_assert(plume_l.visible == false, "Left thruster plume invisible under zero thrust")
	_assert(plume_r.visible == false, "Right thruster plume invisible under zero thrust")

	ship.remove_child(rig)
	rig.free()
	ship.free()

	_start_test("Stress 3.2: Target, Projectile, and Impact shared pool resources")
	var target_mesh: SphereMesh = EntityVisualsBuilder.get_target_mesh()
	var target_mat: StandardMaterial3D = EntityVisualsBuilder.get_target_material()
	_assert(target_mesh != null, "Shared target mesh exists")
	_assert_approx(target_mesh.radius, 3.0, 1e-4, "Target mesh radius is 3.0m (matching hitbox)")
	_assert_approx(target_mesh.height, 6.0, 1e-4, "Target mesh height is 6.0m")
	_assert(target_mat != null and target_mat.emission_enabled, "Shared target material emissive")

	var proj_mesh: BoxMesh = EntityVisualsBuilder.get_projectile_mesh()
	var proj_mat: StandardMaterial3D = EntityVisualsBuilder.get_projectile_material()
	_assert(proj_mesh != null, "Shared projectile mesh exists")
	_assert(proj_mat != null and proj_mat.emission_enabled, "Shared projectile material emissive")

	var impact_mesh: SphereMesh = EntityVisualsBuilder.get_impact_mesh()
	var impact_mat: StandardMaterial3D = EntityVisualsBuilder.get_impact_material()
	_assert(impact_mesh != null, "Shared impact mesh exists")
	_assert(impact_mat != null and impact_mat.emission_enabled, "Shared impact material emissive")

## 4. Touch & Keyboard Coexistence Under Rapid Alternating Events
func _test_touch_keyboard_coexistence_stress() -> void:
	print("\n--- Stress 4: Touch/Keyboard Input Coexistence Stress ---")
	_start_test("Stress 4.1: Alternating rapid multi-touch down/up does not latch enabled")
	var overlay: MobileTouchOverlay = MobileTouchOverlay.new()
	var controller: MobileTouchController = MobileTouchController.new()
	var vp: Vector2 = Vector2(1920.0, 1080.0)

	for cycle in range(50):
		# Touch down
		overlay.handle_touch_point(true, 0, Vector2(250.0, 750.0), vp, controller)
		_assert(controller.enabled == true, "Cycle %d: touch down sets enabled" % cycle)
		# Drag
		overlay.handle_drag_point(0, Vector2(260.0, 740.0), controller)
		_assert(controller.enabled == true, "Cycle %d: touch drag keeps enabled" % cycle)
		# Touch up
		overlay.handle_touch_point(false, 0, Vector2(260.0, 740.0), vp, controller)
		_assert(controller.enabled == false, "Cycle %d: touch up resets enabled to false" % cycle)
		_assert_int(overlay.left_touch_index, -1, "Cycle %d: left_touch_index == -1" % cycle)

## 5. Extended 2,000-Tick Static Memory Gate Stress
func _test_extended_static_memory_gate() -> void:
	print("\n--- Stress 5: Extended 2,000-Tick Static Memory Stress Gate ---")
	_start_test("Stress 5.1: Zero static memory growth over 2,000 live simulation ticks")
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	await process_frame
	await process_frame

	sim.ship.process_user_input = false
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.ship.freeze = true
	sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	sim.ship.linear_velocity = Vector3.ZERO
	sim.ship.angular_velocity = Vector3.ZERO
	sim.guidance.set_mode(FlightGuidanceSystem.MODE_MANUAL)

	var dir: EncounterDirector = sim.encounter_director
	dir.landing_gear.enabled = true
	dir.wind.enabled = true
	dir.power_bus.enabled = true
	dir.propellant.enabled = true
	dir.recorder.recording_enabled = true
	dir.auto_spawn_waves = true
	dir.desired_active_targets = 3
	dir.evasion_enabled = true
	dir.target_initial_health = 1.0e9
	sim.weapon_system.capacitor.enabled = true

	var visual_rig: Node3D = sim.ship.ensure_visual_rig()
	sim.hud.update_hud(sim)
	sim.hud._surface.queue_redraw()

	# Warmup 200 ticks
	for i in range(200):
		sim.step_simulation(DT)
		sim.hud.update_hud(sim)
		sim.hud._surface.queue_redraw()
		EntityVisualsBuilder.update_flight_visuals(visual_rig, sim.ship)

	var mem_before: int = OS.get_static_memory_usage()

	# 2,000 continuous live ticks
	for i in range(2000):
		sim.step_simulation(DT)
		sim.hud.update_hud(sim)
		sim.hud._surface.queue_redraw()
		EntityVisualsBuilder.update_flight_visuals(visual_rig, sim.ship)

	var mem_after: int = OS.get_static_memory_usage()
	var delta: int = mem_after - mem_before
	print("    Extended 2,000 ticks static memory delta: %d bytes (before=%d, after=%d)" % [
		delta, mem_before, mem_after
	])
	_assert(delta <= 0, "Zero static heap growth over 2,000 live ticks (delta=%d <= 0)" % delta)

	sim.destroy()
	get_root().remove_child(sim)
	sim.free()
