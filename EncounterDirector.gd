class_name EncounterDirector
extends RefCounted

## Deterministic orbital wave spawner and Phase 7 subsystem coordinator.

var auto_spawn_waves: bool = false
var desired_active_targets: int = 4
var spawn_radius: float = 350.0
var target_orbital_speed: float = 45.0
var target_initial_health: float = 100.0
var wave_counter: int = 0
var thermal: ThermalStructuralModel = ThermalStructuralModel.new()
var governor: FrameBudgetGovernor = FrameBudgetGovernor.new()
var waypoints: WaypointRingBuffer = WaypointRingBuffer.new()
var evasion_enabled: bool = false
var evasion_amplitude: float = 18.0
var evasion_frequency: float = 2.4
var elapsed_time: float = 0.0
var points_per_kill: int = 100
var points_per_waypoint: int = 250
var combat_score: int = 0
var recorder: FlightRecorderRingBuffer = FlightRecorderRingBuffer.new()
var mission: MissionScenarioRunner = MissionScenarioRunner.new()
var propellant: PropellantMassModel = PropellantMassModel.new()
var proximity: ProximityWarningSystem = ProximityWarningSystem.new()
var wind: PlanetaryWindModel = PlanetaryWindModel.new()
var power_bus: ShipPowerBusModel = ShipPowerBusModel.new()
var landing_gear: LandingGearModel = LandingGearModel.new()
var radar_los: RadarOcclusionModel = RadarOcclusionModel.new()
var _rebase_connected: bool = false
var _guidance: FlightGuidanceSystem = null

func setup_director(sim: PlanetarySimulation) -> void:
	if sim == null or not is_instance_valid(sim.planet_manager):
		return
	governor.reset(sim.planet_manager.lod_split_scale)
	_guidance = sim.guidance
	bind_floating_origin(sim.floating_origin)

func shutdown_director(sim: PlanetarySimulation) -> void:
	if sim != null:
		unbind_floating_origin(sim.floating_origin)
	_guidance = null

func bind_floating_origin(origin: FloatingOrigin) -> void:
	if not is_instance_valid(origin):
		return
	if not origin.origin_rebased.is_connected(rebase_origin):
		origin.origin_rebased.connect(rebase_origin)
	_rebase_connected = true

func unbind_floating_origin(origin: FloatingOrigin) -> void:
	if is_instance_valid(origin) and origin.origin_rebased.is_connected(rebase_origin):
		origin.origin_rebased.disconnect(rebase_origin)
		_rebase_connected = false

func spawn_drone_ring(
	ship_pos: Vector3,
	planet_center: Vector3,
	target_pool: TargetPoolManager,
	count: int = 4
) -> int:
	if not is_instance_valid(target_pool):
		return 0
	var radial_up: Vector3 = ship_pos - planet_center
	radial_up = radial_up.normalized() if radial_up.length_squared() > 1e-12 else Vector3.UP
	var tangent: Vector3 = radial_up.cross(Vector3.RIGHT)
	if tangent.length_squared() < 1e-12:
		tangent = radial_up.cross(Vector3.FORWARD)
	tangent = tangent.normalized()
	var bitangent: Vector3 = radial_up.cross(tangent).normalized()
	var spawn_count: int = clampi(count, 0, TargetPoolManager.POOL_SIZE)
	var phase: float = float(wave_counter) * 0.37
	var spawned: int = 0
	var index: int = 0
	while index < spawn_count:
		var angle: float = TAU * float(index) / maxf(float(spawn_count), 1.0) + phase
		var radial_axis: Vector3 = tangent * cos(angle) + bitangent * sin(angle)
		var tangential_axis: Vector3 = -tangent * sin(angle) + bitangent * cos(angle)
		var target_id: int = target_pool.spawn_target(
			ship_pos + radial_axis * spawn_radius,
			tangential_axis * target_orbital_speed,
			target_initial_health
		)
		if target_id >= 0:
			spawned += 1
		index += 1
	if spawned > 0:
		wave_counter += 1
	return spawned

func step_director(sim: PlanetarySimulation, delta: float) -> void:
	if sim == null or sim.telemetry == null:
		return
	if sim.touch_controller != null and sim.touch_controller.overlay != null:
		if sim.touch_controller.overlay.cycle_mode_requested:
			sim.touch_controller.overlay.cycle_mode_requested = false
			if is_instance_valid(sim.guidance):
				sim.guidance.set_mode((sim.guidance.mode + 1) % 9)
		if sim.touch_controller.overlay.fire_requested:
			sim.touch_controller.overlay.fire_requested = false
			if is_instance_valid(sim.weapon_system):
				sim.weapon_system.fire_projectile()
	if is_instance_valid(sim.weapon_system):
		sim.weapon_system.step_weapon(delta)
	if auto_spawn_waves and is_instance_valid(sim.target_pool) and is_instance_valid(sim.ship):
		if sim.target_pool.active_count == 0:
			spawn_drone_ring(
				sim.ship.global_position,
				sim.planet_manager.planet_center_offset,
				sim.target_pool,
				desired_active_targets
			)
			if is_instance_valid(sim.weapon_system):
				sim.weapon_system.acquire_nearest_target()
	if is_instance_valid(sim.ship):
		sim.ship.ambient_wind_velocity = wind.sample_wind(
			delta,
			sim.ship.global_position,
			sim.planet_manager.planet_center_offset,
			sim.planet_manager.planet_radius,
			sim.ship.atmosphere_ceiling
		)
		var throttle_norm: float = clampf(sim.ship.thrust_input.length(), 0.0, 1.0)
		var w_heat: float = sim.weapon_system.capacitor.get_normalized_heat() \
			if is_instance_valid(sim.weapon_system) else 0.0
		power_bus.step_power_bus(
			delta,
			sim.ship.global_position,
			sim.planet_manager.planet_center_offset,
			sim.planet_manager.planet_radius,
			throttle_norm,
			w_heat,
			sim.weapon_system.capacitor if is_instance_valid(sim.weapon_system) else null
		)
		step_evasion(
			delta,
			sim.ship.global_position,
			sim.planet_manager.planet_center_offset,
			sim.target_pool
		)
		waypoints.step_waypoints(sim.ship.global_position)
		if is_instance_valid(sim.guidance):
			sim.guidance.set_waypoint_target(
				waypoints.current_waypoint_id >= 0, waypoints.get_current_waypoint_position()
			)
		landing_gear.step_gear(
			delta, sim.telemetry.radar_altitude_agl, sim.telemetry.vertical_speed,
			sim.ship, thermal
		)
		radar_los.step_radar_los(
			sim.ship.global_position, sim.planet_manager.planet_center_offset,
			sim.planet_manager.planet_radius, sim.weapon_system, sim.target_pool, waypoints
		)
	mission.step_mission(delta, sim, self)
	sim.telemetry.active_waypoints = waypoints.active_count
	sim.telemetry.completed_waypoints = waypoints.completed_waypoints
	sim.telemetry.waypoint_distance = waypoints.distance_to_current
	var air_speed: float = (sim.ship.linear_velocity - sim.ship.ambient_wind_velocity).length() \
		if is_instance_valid(sim.ship) else sim.telemetry.total_speed
	thermal.step_thermal(
		delta,
		sim.telemetry.air_density,
		air_speed,
		sim.telemetry.g_load
	)
	sim.telemetry.surface_temperature_k = thermal.surface_temperature_k
	sim.telemetry.heat_shield_load = thermal.heat_shield_load
	sim.telemetry.hull_integrity = thermal.hull_integrity
	sim.telemetry.ema_frame_ms = governor.ema_frame_ms
	sim.telemetry.governor_split_scale = governor.recommended_split_scale
	if is_instance_valid(sim.ship):
		recorder.step_recorder(
			delta,
			sim.ship.global_position,
			sim.ship.linear_velocity,
			sim.telemetry,
			sim.guidance.mode if is_instance_valid(sim.guidance) else 0
		)
		propellant.step_propellant(delta, sim.ship)
		proximity.evaluate_proximity(
			sim.telemetry.radar_altitude_agl,
			sim.telemetry.vertical_speed,
			sim.ship.global_position,
			sim.target_pool
		)
	var kills: int = sim.target_pool.destroyed_count if is_instance_valid(sim.target_pool) else 0
	var bonus: int = mission.mission_bonus_points if mission.is_completed() else 0
	combat_score = kills * points_per_kill + waypoints.completed_waypoints * points_per_waypoint + bonus
	sim.telemetry.targets_destroyed = kills
	sim.telemetry.combat_score = combat_score
	sim.telemetry.mission_stage = mission.stage
	sim.telemetry.recorded_samples = recorder.count
	sim.telemetry.fuel_fraction = propellant.get_fuel_fraction()
	sim.telemetry.remaining_delta_v = propellant.get_remaining_delta_v()
	sim.telemetry.proximity_alert = proximity.alert_level
	sim.telemetry.time_to_impact = proximity.time_to_impact
	sim.telemetry.weapon_heat = sim.weapon_system.capacitor.get_normalized_heat() \
		if is_instance_valid(sim.weapon_system) else 0.0
	sim.telemetry.weapon_overheated = sim.weapon_system.capacitor.overheated \
		if is_instance_valid(sim.weapon_system) else false
	sim.telemetry.wind_speed = wind.current_wind_speed
	sim.telemetry.battery_fraction = power_bus.get_battery_fraction()
	sim.telemetry.in_eclipse = power_bus.in_eclipse
	sim.telemetry.power_brownout = power_bus.brownout
	sim.telemetry.gear_deploy_progress = landing_gear.deploy_progress
	sim.telemetry.weight_on_wheels = landing_gear.weight_on_wheels
	sim.telemetry.target_los_clear = radar_los.target_los_clear
	sim.telemetry.waypoint_signal_strength = radar_los.waypoint_signal_strength

func rebase_origin(offset: Vector3) -> void:
	waypoints.rebase_origin(offset)
	recorder.rebase_origin(offset)
	if is_instance_valid(_guidance) and _guidance.waypoint_target_active:
		_guidance.waypoint_target_pos -= offset

func step_evasion(
	delta: float,
	ship_pos: Vector3,
	planet_center: Vector3,
	target_pool: TargetPoolManager
) -> void:
	elapsed_time += maxf(delta, 0.0)
	if not evasion_enabled or not is_instance_valid(target_pool):
		return
	var radial_up: Vector3 = ship_pos - planet_center
	radial_up = radial_up.normalized() if radial_up.length_squared() > 1e-12 else Vector3.UP
	var dt: float = maxf(delta, 0.0)
	var id: int = 0
	while id < TargetPoolManager.POOL_SIZE:
		if target_pool.is_in_use[id]:
			var velocity: Vector3 = target_pool.velocities[id]
			var speed: float = velocity.length()
			if speed > 1e-6:
				var lateral: Vector3 = velocity.cross(radial_up)
				if lateral.length_squared() < 1e-12:
					lateral = velocity.cross(Vector3.FORWARD)
				if lateral.length_squared() < 1e-12:
					lateral = velocity.cross(Vector3.RIGHT)
				lateral = lateral.normalized()
				var phase: float = elapsed_time * evasion_frequency + float(id) * 1.5707963
				var weave: Vector3 = (
					lateral * cos(phase) + radial_up * sin(phase)
				) * evasion_amplitude * dt
				velocity += weave
				target_pool.velocities[id] = velocity.normalized() * target_orbital_speed
		id += 1
