class_name FlightRecorderRingBuffer
extends RefCounted

## Fixed 64-slot black-box recorder for rebase-aware flight and sortie snapshots.

const CAPACITY: int = 64
const WP_CAP: int = WaypointRingBuffer.MAX_WAYPOINTS
const TGT_CAP: int = TargetPoolManager.POOL_SIZE

var recording_enabled: bool = false
var sample_interval: float = 0.25
var time_since_last_sample: float = 0.0
var head: int = 0
var count: int = 0
var total_recorded: int = 0

var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var g_loads: PackedFloat32Array = PackedFloat32Array()
var temperatures_k: PackedFloat32Array = PackedFloat32Array()
var hull_integrities: PackedFloat32Array = PackedFloat32Array()
var guidance_modes: PackedByteArray = PackedByteArray()

var has_sortie_state: PackedByteArray = PackedByteArray()
var ship_orientations: Array[Basis] = []
var heat_shield_loads: PackedFloat32Array = PackedFloat32Array()
var propellant_masses: PackedFloat32Array = PackedFloat32Array()
var battery_whs: PackedFloat32Array = PackedFloat32Array()
var weapon_heats: PackedFloat32Array = PackedFloat32Array()
var mission_stages: PackedByteArray = PackedByteArray()
var mission_start_wp: PackedInt32Array = PackedInt32Array()
var mission_start_tgts: PackedInt32Array = PackedInt32Array()
var combat_scores: PackedInt32Array = PackedInt32Array()
var gear_deployed_arr: PackedByteArray = PackedByteArray()
var gear_progress_arr: PackedFloat32Array = PackedFloat32Array()
var wp_completed: PackedInt32Array = PackedInt32Array()
var wp_current_id: PackedInt32Array = PackedInt32Array()
var wp_active: PackedByteArray = PackedByteArray()
var wp_positions: PackedVector3Array = PackedVector3Array()
var wp_radii: PackedFloat32Array = PackedFloat32Array()
var tgt_destroyed: PackedInt32Array = PackedInt32Array()
var tgt_active: PackedByteArray = PackedByteArray()
var tgt_positions: PackedVector3Array = PackedVector3Array()
var tgt_velocities: PackedVector3Array = PackedVector3Array()
var tgt_healths: PackedFloat32Array = PackedFloat32Array()
var locked_target_ids: PackedInt32Array = PackedInt32Array()

var _sim_ref: WeakRef = null
var _director_ref: WeakRef = null

func _init() -> void:
	positions.resize(CAPACITY); velocities.resize(CAPACITY)
	g_loads.resize(CAPACITY); temperatures_k.resize(CAPACITY)
	hull_integrities.resize(CAPACITY); guidance_modes.resize(CAPACITY)
	has_sortie_state.resize(CAPACITY); ship_orientations.resize(CAPACITY)
	heat_shield_loads.resize(CAPACITY); propellant_masses.resize(CAPACITY)
	battery_whs.resize(CAPACITY); weapon_heats.resize(CAPACITY)
	mission_stages.resize(CAPACITY); mission_start_wp.resize(CAPACITY)
	mission_start_tgts.resize(CAPACITY); combat_scores.resize(CAPACITY)
	gear_deployed_arr.resize(CAPACITY); gear_progress_arr.resize(CAPACITY)
	wp_completed.resize(CAPACITY); wp_current_id.resize(CAPACITY)
	wp_active.resize(CAPACITY * WP_CAP); wp_positions.resize(CAPACITY * WP_CAP)
	wp_radii.resize(CAPACITY * WP_CAP); tgt_destroyed.resize(CAPACITY)
	tgt_active.resize(CAPACITY * TGT_CAP); tgt_positions.resize(CAPACITY * TGT_CAP)
	tgt_velocities.resize(CAPACITY * TGT_CAP); tgt_healths.resize(CAPACITY * TGT_CAP)
	locked_target_ids.resize(CAPACITY)
	clear()

func bind_context(sim: Node, director: RefCounted) -> void:
	_sim_ref = weakref(sim) if sim != null else null
	_director_ref = weakref(director) if director != null else null

func unbind_context() -> void:
	_sim_ref = null
	_director_ref = null

func clear() -> void:
	head = 0; count = 0; total_recorded = 0; time_since_last_sample = 0.0
	for slot in range(CAPACITY):
		positions[slot] = Vector3.ZERO; velocities[slot] = Vector3.ZERO
		g_loads[slot] = 0.0; temperatures_k[slot] = 0.0
		hull_integrities[slot] = 0.0; guidance_modes[slot] = 0
		has_sortie_state[slot] = 0; ship_orientations[slot] = Basis.IDENTITY
		heat_shield_loads[slot] = 0.0; propellant_masses[slot] = 0.0
		battery_whs[slot] = 0.0; weapon_heats[slot] = 0.0
		mission_stages[slot] = 0; mission_start_wp[slot] = 0
		mission_start_tgts[slot] = 0; combat_scores[slot] = 0
		gear_deployed_arr[slot] = 1; gear_progress_arr[slot] = 1.0
		wp_completed[slot] = 0; wp_current_id[slot] = -1
		tgt_destroyed[slot] = 0; locked_target_ids[slot] = -1

func record_snapshot(
	pos: Vector3, vel: Vector3, g_load: float, temp_k: float, hull: float, mode: int
) -> int:
	var slot: int = head
	positions[slot] = pos; velocities[slot] = vel
	g_loads[slot] = g_load; temperatures_k[slot] = temp_k
	hull_integrities[slot] = hull; guidance_modes[slot] = clampi(mode, 0, 8)
	_capture_sortie_slot(slot)
	head = (head + 1) % CAPACITY
	count = mini(count + 1, CAPACITY)
	total_recorded += 1
	return slot

func _capture_sortie_slot(slot: int) -> void:
	var dir: EncounterDirector = _director_ref.get_ref() as EncounterDirector if _director_ref != null else null
	var sim: PlanetarySimulation = _sim_ref.get_ref() as PlanetarySimulation if _sim_ref != null else null
	if dir == null:
		has_sortie_state[slot] = 0
		return
	has_sortie_state[slot] = 1
	heat_shield_loads[slot] = dir.thermal.heat_shield_load
	propellant_masses[slot] = dir.propellant.propellant_mass
	battery_whs[slot] = dir.power_bus.battery_wh
	mission_stages[slot] = dir.mission.stage
	mission_start_wp[slot] = dir.mission._start_completed_waypoints
	mission_start_tgts[slot] = dir.mission._start_destroyed_targets
	combat_scores[slot] = dir.combat_score
	gear_deployed_arr[slot] = 1 if dir.landing_gear.deployed else 0
	gear_progress_arr[slot] = dir.landing_gear.deploy_progress
	wp_completed[slot] = dir.waypoints.completed_waypoints
	wp_current_id[slot] = dir.waypoints.current_waypoint_id
	var wp_base: int = slot * WP_CAP
	for i in range(WP_CAP):
		wp_active[wp_base + i] = dir.waypoints.is_active[i]
		wp_positions[wp_base + i] = dir.waypoints.positions[i]
		wp_radii[wp_base + i] = dir.waypoints.radii[i]
	if sim != null and is_instance_valid(sim.ship):
		ship_orientations[slot] = sim.ship.global_transform.basis if sim.ship.is_inside_tree() else sim.ship.transform.basis
	if sim != null and is_instance_valid(sim.weapon_system):
		weapon_heats[slot] = sim.weapon_system.capacitor.heat
		locked_target_ids[slot] = sim.weapon_system.locked_target_id
	if sim != null and is_instance_valid(sim.target_pool):
		tgt_destroyed[slot] = sim.target_pool.destroyed_count
		var t_base: int = slot * TGT_CAP
		for i in range(TGT_CAP):
			tgt_active[t_base + i] = 1 if sim.target_pool.is_in_use[i] else 0
			tgt_positions[t_base + i] = sim.target_pool.positions[i]
			tgt_velocities[t_base + i] = sim.target_pool.velocities[i]
			tgt_healths[t_base + i] = sim.target_pool.health[i]

func step_recorder(
	delta: float, ship_pos: Vector3, ship_vel: Vector3, telemetry: SimulationTelemetry, mode: int
) -> bool:
	if not recording_enabled or telemetry == null:
		return false
	time_since_last_sample += maxf(delta, 0.0)
	if time_since_last_sample < sample_interval:
		return false
	time_since_last_sample = fmod(time_since_last_sample, maxf(sample_interval, 0.001))
	record_snapshot(ship_pos, ship_vel, telemetry.g_load, telemetry.surface_temperature_k, telemetry.hull_integrity, mode)
	return true

func get_latest_slot() -> int:
	return -1 if count == 0 else (head - 1 + CAPACITY) % CAPACITY

func restore_snapshot(
	slot: int, ship: SpaceshipController, thermal: ThermalStructuralModel = null, guidance: FlightGuidanceSystem = null
) -> bool:
	if slot < 0 or slot >= count or slot >= CAPACITY or not is_instance_valid(ship):
		return false
	if ship.is_inside_tree():
		ship.global_position = positions[slot]
		if has_sortie_state[slot] != 0:
			ship.global_transform = Transform3D(ship_orientations[slot], positions[slot])
	else:
		ship.position = positions[slot]
		if has_sortie_state[slot] != 0:
			ship.transform = Transform3D(ship_orientations[slot], positions[slot])
	ship.linear_velocity = velocities[slot]; ship.angular_velocity = Vector3.ZERO
	if ship.is_inside_tree():
		PhysicsServer3D.body_set_state(ship.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, ship.global_transform)
		PhysicsServer3D.body_set_state(ship.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, velocities[slot])
		PhysicsServer3D.body_set_state(ship.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	if is_instance_valid(thermal):
		thermal.surface_temperature_k = temperatures_k[slot]
		thermal.hull_integrity = hull_integrities[slot]
		if has_sortie_state[slot] != 0:
			thermal.heat_shield_load = heat_shield_loads[slot]
			thermal.is_overheating = thermal.surface_temperature_k > thermal.max_safe_temperature_k
	if is_instance_valid(guidance):
		guidance.set_mode(int(guidance_modes[slot]))
	if has_sortie_state[slot] != 0:
		_restore_sortie_slot(slot, ship)
	return true

func _restore_sortie_slot(slot: int, ship: SpaceshipController) -> void:
	var dir: EncounterDirector = _director_ref.get_ref() as EncounterDirector if _director_ref != null else null
	var sim: PlanetarySimulation = _sim_ref.get_ref() as PlanetarySimulation if _sim_ref != null else null
	if dir == null:
		return
	dir.propellant.propellant_mass = propellant_masses[slot]
	dir.propellant.fuel_depleted = propellant_masses[slot] <= 0.0
	if dir.propellant.enabled:
		ship.mass = dir.propellant.get_wet_mass(); ship.thrust_cutoff = dir.propellant.fuel_depleted
	dir.power_bus.battery_wh = battery_whs[slot]; dir.power_bus.brownout = battery_whs[slot] <= 0.0
	dir.mission.stage = int(mission_stages[slot])
	dir.mission._start_completed_waypoints = mission_start_wp[slot]
	dir.mission._start_destroyed_targets = mission_start_tgts[slot]
	dir.combat_score = combat_scores[slot]
	dir.landing_gear.deployed = gear_deployed_arr[slot] != 0; dir.landing_gear.deploy_progress = gear_progress_arr[slot]
	dir.landing_gear.weight_on_wheels = false; dir.landing_gear.contact_duration = 0.0
	dir.waypoints.completed_waypoints = wp_completed[slot]; dir.waypoints.current_waypoint_id = wp_current_id[slot]
	var wp_base: int = slot * WP_CAP; var wp_cnt: int = 0
	for i in range(WP_CAP):
		dir.waypoints.is_active[i] = wp_active[wp_base + i]
		dir.waypoints.positions[i] = wp_positions[wp_base + i]; dir.waypoints.radii[i] = wp_radii[wp_base + i]
		if wp_active[wp_base + i] != 0: wp_cnt += 1
	dir.waypoints.active_count = wp_cnt
	if sim == null: return
	if is_instance_valid(sim.weapon_system):
		sim.weapon_system.capacitor.heat = weapon_heats[slot]
		sim.weapon_system.capacitor.overheated = weapon_heats[slot] >= sim.weapon_system.capacitor.max_heat
		sim.weapon_system.locked_target_id = locked_target_ids[slot]
	if is_instance_valid(sim.projectile_pool): sim.projectile_pool.clear()
	if is_instance_valid(sim.impact_pool): sim.impact_pool.clear()
	if is_instance_valid(sim.target_pool):
		var tp: TargetPoolManager = sim.target_pool
		tp.destroyed_count = tgt_destroyed[slot]; tp.free_indices.clear(); tp.active_count = 0
		var t_base: int = slot * TGT_CAP
		for i in range(TGT_CAP):
			var act: bool = tgt_active[t_base + i] != 0
			tp.is_in_use[i] = act; tp.shapes[i].disabled = not act; tp.markers[i].visible = act
			tp.positions[i] = tgt_positions[t_base + i]; tp.velocities[i] = tgt_velocities[t_base + i]; tp.health[i] = tgt_healths[t_base + i]
			if act: tp.active_count += 1; tp.markers[i].position = tp.positions[i]; tp._sync_body_transform(i)
			else: tp.free_indices.push_back(i)

func rebase_origin(offset: Vector3) -> void:
	if offset == Vector3.ZERO or count == 0:
		return
	for slot in range(CAPACITY):
		positions[slot] -= offset
		if has_sortie_state[slot] != 0:
			var wp_base: int = slot * WP_CAP
			for i in range(WP_CAP):
				if wp_active[wp_base + i] != 0: wp_positions[wp_base + i] -= offset
			var t_base: int = slot * TGT_CAP
			for i in range(TGT_CAP):
				if tgt_active[t_base + i] != 0: tgt_positions[t_base + i] -= offset
