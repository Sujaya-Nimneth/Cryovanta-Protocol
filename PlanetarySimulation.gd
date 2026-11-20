class_name PlanetarySimulation
extends Node3D

## Unified simulation root. Builds and wires all runtime systems once.

@export var synchronous_streaming: bool = false
@export var auto_step: bool = true
@export var camera_local_offset: Vector3 = Vector3(0.0, 3.0, 8.0)
@export var initial_altitude: float = 1000.0

var planet_manager: PlanetManager = null
var planet_streamer: PlanetStreamer = null
var floating_origin: FloatingOrigin = null
var ship: SpaceshipController = null
var projectile_pool: ProjectilePoolManager = null
var target_pool: TargetPoolManager = null
var impact_pool: ImpactEffectPoolManager = null
var touch_controller: MobileTouchController = null
var weapon_system: SpaceshipWeaponSystem = null
var guidance: FlightGuidanceSystem = null
var telemetry: SimulationTelemetry = null
var encounter_director: EncounterDirector = null
var surface_material: PlanetSurfaceMaterial = null
var environment: PlanetaryEnvironment = null
var hud: CockpitHUD = null
var camera: Camera3D = null
var is_setup: bool = false
var sortie_paused: bool = false

var _rebase_callables: Array[Callable] = []
var _last_render_usec: int = 0
var _ship_collision_shape: CollisionShape3D = null
var _ship_sphere: SphereShape3D = null
var _space_state: PhysicsDirectSpaceState3D = null

func _ready() -> void:
	if not is_setup:
		setup_simulation(synchronous_streaming)

func _physics_process(delta: float) -> void:
	if auto_step and is_setup:
		step_simulation(delta, _get_space_state())

func _process(_delta: float) -> void:
	if not auto_step or not is_setup:
		return
	var now_usec: int = Time.get_ticks_usec()
	if _last_render_usec > 0:
		sample_render_frame(float(now_usec - _last_render_usec) * 0.001)
	_last_render_usec = now_usec

func sample_render_frame(frame_ms: float) -> void:
	if encounter_director == null or encounter_director.governor == null:
		return
	encounter_director.governor.sample_frame_time(clampf(frame_ms, 0.1, 100.0), planet_manager)
	telemetry.ema_frame_ms = encounter_director.governor.ema_frame_ms
	telemetry.governor_split_scale = encounter_director.governor.recommended_split_scale

func setup_simulation(synchronous_streaming_mode: bool = false) -> void:
	if is_setup:
		return
	synchronous_streaming = synchronous_streaming_mode
	FlightInputBindings.ensure_default_actions()
	planet_manager = PlanetManager.new()
	planet_manager.name = "PlanetManager"
	add_child(planet_manager)
	var startup_offset := Vector3(0.0, planet_manager.planet_radius + initial_altitude, 0.0)
	planet_manager.rebase_origin(startup_offset)

	planet_streamer = PlanetStreamer.new()
	planet_streamer.name = "PlanetStreamer"
	add_child(planet_streamer)
	planet_streamer.setup(planet_manager, null, synchronous_streaming)
	surface_material = PlanetSurfaceMaterial.new()
	surface_material.update_planet_center_From_manager(planet_manager)
	surface_material.apply_to_streamer(planet_streamer)

	ship = SpaceshipController.new()
	ship.name = "Spaceship"
	ship.planet_manager = planet_manager
	ship.enable_planetary_gravity = true
	ship.collision_layer = 2
	ship.collision_mask = 1
	ship.position = Vector3(0.0, 0.0, 0.0)
	ship.mass = 1000.0
	ship.inertia = Vector3(2000.0, 2000.0, 3000.0)
	add_child(ship)
	ship.ensure_visual_rig()
	ship.set_physics_process(false)
	_ship_sphere = SphereShape3D.new()
	_ship_sphere.radius = 2.0
	_ship_collision_shape = CollisionShape3D.new()
	_ship_collision_shape.name = "ShipCollision"
	_ship_collision_shape.shape = _ship_sphere
	ship.add_child(_ship_collision_shape)

	camera = Camera3D.new()
	camera.name = "FlightCamera"
	camera.position = camera_local_offset
	camera.current = true; camera.far = 250_000.0
	ship.add_child(camera)

	projectile_pool = ProjectilePoolManager.new()
	projectile_pool.name = "ProjectilePool"
	add_child(projectile_pool)

	target_pool = TargetPoolManager.new()
	target_pool.name = "TargetPool"
	add_child(target_pool)

	impact_pool = ImpactEffectPoolManager.new()
	impact_pool.name = "ImpactPool"
	add_child(impact_pool)
	projectile_pool.target_pool = target_pool
	projectile_pool.impact_pool = impact_pool

	weapon_system = SpaceshipWeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	weapon_system.ship = ship
	weapon_system.projectile_pool = projectile_pool
	weapon_system.target_pool = target_pool
	weapon_system.planet_manager = planet_manager
	add_child(weapon_system)
	touch_controller = MobileTouchController.new()

	guidance = FlightGuidanceSystem.new()
	guidance.name = "FlightGuidance"
	guidance.ship = ship
	guidance.weapon_system = weapon_system
	guidance.planet_manager = planet_manager
	add_child(guidance)

	environment = PlanetaryEnvironment.new()
	environment.name = "PlanetaryEnvironment"
	add_child(environment)

	hud = CockpitHUD.new()
	hud.name = "CockpitHUD"
	add_child(hud)

	telemetry = SimulationTelemetry.new()
	encounter_director = EncounterDirector.new()
	floating_origin = FloatingOrigin.new()
	floating_origin.name = "FloatingOrigin"
	floating_origin.player_node = ship
	floating_origin.planet_manager = planet_manager
	floating_origin.set_physics_process(false)
	add_child(floating_origin)
	_rebase_callables = [
		planet_streamer.rebase_origin, projectile_pool.rebase_origin,
		target_pool.rebase_origin, impact_pool.rebase_origin, hud.rebase_origin,
		Callable(surface_material, "update_planet_center_From_manager").bind(planet_manager)
	]
	for cb: Callable in _rebase_callables:
		floating_origin.origin_rebased.connect(cb)
	encounter_director.setup_director(self)
	is_setup = true
	_last_render_usec = 0
	if auto_step:
		LiveSortieBootstrap.activate_live_sortie(self)
func step_simulation(delta: float, space_state: PhysicsDirectSpaceState3D = null) -> void:
	if not is_setup:
		return
	var _t0: int = Time.get_ticks_usec()
	if ship.process_user_input:
		if Input.is_action_just_pressed(&"pause_sortie"): LiveSortieBootstrap.toggle_pause(self)
		if Input.is_action_just_pressed(&"restart_sortie"): LiveSortieBootstrap.restart_sortie(self)
	if sortie_paused: hud.update_hud(self); return
	if ship.process_user_input:
		if Input.is_action_just_pressed(&"rewind_flight"): LiveSortieBootstrap.trigger_rewind(self)
		if Input.is_action_just_pressed(&"cycle_guidance_mode"): guidance.set_mode((guidance.mode + 1) % 9)
		if guidance.mode == FlightGuidanceSystem.MODE_MANUAL:
			if touch_controller.enabled:
				touch_controller.apply_to_ship(ship)
			else:
				ship._sample_user_input()
		if Input.is_action_just_pressed(&"fire_weapon"):
			weapon_system.fire_projectile()
	guidance.update_guidance(delta, space_state)
	ship._apply_flight_forces()
	floating_origin.check_rebase()
	target_pool.step_targets(delta)
	var locked_id: int = weapon_system.locked_target_id
	if target_pool.active_count == 0:
		weapon_system.locked_target_id = -1
	elif locked_id < 0 or locked_id >= target_pool.is_in_use.size() \
			or not target_pool.is_in_use[locked_id]:
		weapon_system.acquire_nearest_target(ship.global_position, target_pool)
	impact_pool.step_effects(delta)
	projectile_pool.step_projectiles(delta, space_state, planet_manager.planet_center_offset, planet_manager.planet_radius, ship.surface_gravity)
	var _t1: int = Time.get_ticks_usec()
	planet_streamer.update_streamer(camera.global_position)
	var _t2: int = Time.get_ticks_usec()
	telemetry.sample(self, space_state)
	environment.update_environment(
		ship.global_position, planet_manager.planet_center_offset,
		planet_manager.planet_radius, ship.atmosphere_ceiling, ship.surface_air_density,
		clampf(ship.thrust_input.length(), 0.0, 1.0), telemetry.proximity_alert, telemetry.weapon_heat, delta
	)
	if encounter_director != null:
		encounter_director.step_director(self, delta)
	hud.update_hud(self)
	telemetry.record_step_timings(_t0, _t1, _t2, Time.get_ticks_usec())

func _get_space_state() -> PhysicsDirectSpaceState3D:
	if is_inside_tree():
		_space_state = get_world_3d().direct_space_state
	return _space_state

func destroy() -> void:
	if not is_setup:
		return
	is_setup = false
	if encounter_director != null: encounter_director.shutdown_director(self)
	if floating_origin != null:
		for cb: Callable in _rebase_callables:
			if cb.is_valid() and floating_origin.origin_rebased.is_connected(cb):
				floating_origin.origin_rebased.disconnect(cb)
		_rebase_callables.clear()
	if planet_streamer != null: planet_streamer.destroy()
	if projectile_pool != null: projectile_pool.clear()
	if target_pool != null: target_pool.clear()
	if impact_pool != null: impact_pool.clear()
	for n: Node in [guidance, hud, environment, weapon_system, floating_origin,
			projectile_pool, target_pool, impact_pool, planet_streamer, ship]:
		_free_owned_node(n)
	guidance = null; hud = null; environment = null; weapon_system = null
	floating_origin = null; projectile_pool = null; target_pool = null
	impact_pool = null; planet_streamer = null; ship = null; camera = null
	_ship_collision_shape = null; _ship_sphere = null
	if planet_manager != null:
		planet_manager.destroy()
		_free_owned_node(planet_manager)
	planet_manager = null
	telemetry = null; encounter_director = null
	surface_material = null; touch_controller = null

func _free_owned_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() == self:
		remove_child(node)
	node.free()
