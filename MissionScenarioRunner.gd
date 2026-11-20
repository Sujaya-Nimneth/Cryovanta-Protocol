class_name MissionScenarioRunner
extends RefCounted

## Deterministic multi-stage sortie state machine with fixed scalar registers.

const STAGE_INACTIVE: int = 0
const STAGE_WAYPOINT_RECON: int = 1
const STAGE_ORBITAL_INTERCEPT: int = 2
const STAGE_SOFT_LANDING: int = 3
const STAGE_COMPLETED: int = 4
const STAGE_FAILED: int = 5

var stage: int = STAGE_INACTIVE
var mission_elapsed: float = 0.0
var recon_waypoints_required: int = 1
var intercept_kills_required: int = 2
var landing_altitude_threshold: float = 25.0
var landing_speed_threshold: float = 5.0
var mission_bonus_points: int = 500
var _start_completed_waypoints: int = 0
var _start_destroyed_targets: int = 0

func reset() -> void:
	stage = STAGE_INACTIVE
	mission_elapsed = 0.0
	_start_completed_waypoints = 0
	_start_destroyed_targets = 0

func start_mission(
	director: EncounterDirector,
	target_pool: TargetPoolManager,
	ship_pos: Vector3,
	forward_dir: Vector3
) -> void:
	mission_elapsed = 0.0
	if director == null:
		stage = STAGE_FAILED
		return
	_start_completed_waypoints = director.waypoints.completed_waypoints
	_start_destroyed_targets = target_pool.destroyed_count if is_instance_valid(target_pool) else 0
	if director.waypoints.active_count == 0:
		var forward: Vector3 = forward_dir.normalized()
		if forward.length_squared() < 1e-12:
			forward = Vector3.FORWARD
		director.waypoints.add_waypoint(ship_pos + forward * 300.0, 60.0)
	stage = STAGE_WAYPOINT_RECON

func step_mission(
	delta: float,
	sim: PlanetarySimulation,
	director: EncounterDirector
) -> int:
	if stage == STAGE_INACTIVE or stage == STAGE_COMPLETED or stage == STAGE_FAILED \
		or sim == null or director == null:
		return stage
	mission_elapsed += maxf(delta, 0.0)
	if director.thermal.hull_integrity <= 0.0:
		stage = STAGE_FAILED
		return stage
	match stage:
		STAGE_WAYPOINT_RECON:
			if director.waypoints.completed_waypoints - _start_completed_waypoints \
				>= recon_waypoints_required:
				stage = STAGE_ORBITAL_INTERCEPT
				if is_instance_valid(sim.target_pool) and sim.target_pool.active_count == 0:
					director.spawn_drone_ring(
						sim.ship.global_position,
						sim.planet_manager.planet_center_offset,
						sim.target_pool,
						maxi(intercept_kills_required, 2)
					)
					if is_instance_valid(sim.weapon_system):
						sim.weapon_system.acquire_nearest_target()
		STAGE_ORBITAL_INTERCEPT:
			var kills: int = sim.target_pool.destroyed_count \
				if is_instance_valid(sim.target_pool) else 0
			if kills - _start_destroyed_targets >= intercept_kills_required:
				stage = STAGE_SOFT_LANDING
		STAGE_SOFT_LANDING:
			var gear_ok: bool = director.landing_gear != null and director.landing_gear.deployed \
				and director.landing_gear.weight_on_wheels \
				and director.landing_gear.surface_clearance <= 0.5
			var sink_rate: float = maxf(-sim.telemetry.vertical_speed, 0.0)
			if gear_ok and sim.telemetry.total_speed <= landing_speed_threshold and sink_rate <= 3.0:
				stage = STAGE_COMPLETED
	return stage

func is_completed() -> bool:
	return stage == STAGE_COMPLETED
