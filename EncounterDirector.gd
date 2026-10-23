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
	thermal.step_thermal(
		delta,
		sim.telemetry.air_density,
		sim.telemetry.total_speed,
		sim.telemetry.g_load
	)
	sim.telemetry.surface_temperature_k = thermal.surface_temperature_k
	sim.telemetry.heat_shield_load = thermal.heat_shield_load
	sim.telemetry.hull_integrity = thermal.hull_integrity
	governor.sample_frame_time(delta * 1000.0, sim.planet_manager)
	sim.telemetry.ema_frame_ms = governor.ema_frame_ms
	sim.telemetry.governor_split_scale = governor.recommended_split_scale
