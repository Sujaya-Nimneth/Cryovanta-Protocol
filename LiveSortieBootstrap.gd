class_name LiveSortieBootstrap
extends RefCounted

## Live sortie configurator for auto_step mode.
## Activates Phase 7-13 subsystems, synchronizes sun direction,
## bootstraps initial coarse chunks, and manages flight rewind.

static func activate_live_sortie(sim: PlanetarySimulation) -> void:
	if sim == null or not is_instance_valid(sim):
		return

	# 1. Enable ship user controls and baseline physics
	if is_instance_valid(sim.ship):
		sim.ship.process_user_input = true
		if is_equal_approx(sim.ship.mass, 1.0):
			sim.ship.mass = 1000.0
		if sim.ship.inertia == Vector3.ZERO:
			sim.ship.inertia = Vector3(2000.0, 2000.0, 3000.0)

	# 2. Activate weapon heat capacitor
	if is_instance_valid(sim.weapon_system) and is_instance_valid(sim.weapon_system.capacitor):
		sim.weapon_system.capacitor.enabled = true
		sim.weapon_system.capacitor.reset()

	# 3. Activate encounter director subsystems
	var dir: EncounterDirector = sim.encounter_director
	if is_instance_valid(dir):
		# Propellant (applies 1600.0 kg wet mass)
		if is_instance_valid(dir.propellant):
			dir.propellant.enabled = true
			dir.propellant.reset(sim.ship)
			if is_instance_valid(sim.ship):
				sim.ship.mass = dir.propellant.get_wet_mass()

		# Atmospheric wind and turbulence
		if is_instance_valid(dir.wind):
			dir.wind.enabled = true
			dir.wind.reset()

		# Ship power bus and sun direction synchronization
		if is_instance_valid(dir.power_bus):
			dir.power_bus.enabled = true
			dir.power_bus.reset()
			if is_instance_valid(sim.environment) and is_instance_valid(sim.environment.sun_light):
				dir.power_bus.sun_direction = sim.environment.sun_light.global_transform.basis.z.normalized()

		# Landing gear (retracted for cruise spawn)
		if is_instance_valid(dir.landing_gear):
			dir.landing_gear.enabled = true
			dir.landing_gear.deployed = false
			dir.landing_gear.deploy_progress = 0.0
			if is_instance_valid(sim.ship):
				sim.ship.drag_coefficient = dir.landing_gear.retracted_drag_coeff

		# Terrain proximity and radar line-of-sight occlusion
		if is_instance_valid(dir.proximity):
			dir.proximity.reset()
		if is_instance_valid(dir.radar_los):
			dir.radar_los.reset()

		# Flight recorder, drone evasion, and wave spawner
		if is_instance_valid(dir.recorder):
			dir.recorder.recording_enabled = true
			dir.recorder.clear()
		dir.evasion_enabled = true
		dir.auto_spawn_waves = true

		# Start 3-stage mission sortie
		if is_instance_valid(dir.mission):
			var forward: Vector3 = (
				-sim.ship.global_transform.basis.z.normalized()
				if is_instance_valid(sim.ship)
				else Vector3.FORWARD
			)
			dir.mission.start_mission(
				dir,
				sim.target_pool,
				sim.ship.global_position if is_instance_valid(sim.ship) else Vector3.ZERO,
				forward
			)

	# 4. Synchronous initial chunk bootstrap before frame 0
	if is_instance_valid(sim.planet_streamer):
		var was_sync: bool = sim.planet_streamer.synchronous_mode
		sim.planet_streamer.synchronous_mode = true
		var cam_pos: Vector3 = sim.camera.global_position if is_instance_valid(sim.camera) else Vector3.ZERO
		sim.planet_streamer.update_streamer(cam_pos)
		sim.planet_streamer.synchronous_mode = was_sync

static func trigger_rewind(sim: PlanetarySimulation) -> bool:
	if sim == null or not is_instance_valid(sim) or sim.encounter_director == null:
		return false
	var rec: FlightRecorderRingBuffer = sim.encounter_director.recorder
	if rec == null or rec.count == 0:
		return false
	var slot: int = rec.get_latest_slot()
	if slot < 0:
		return false
	var ok: bool = rec.restore_snapshot(slot, sim.ship, sim.encounter_director.thermal, sim.guidance)
	if ok and is_instance_valid(sim.ship):
		sim.ship.angular_velocity = Vector3.ZERO
		if sim.ship.is_inside_tree():
			PhysicsServer3D.body_set_state(
				sim.ship.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO
			)
	return ok

static func toggle_pause(sim: PlanetarySimulation) -> bool:
	if sim == null or not is_instance_valid(sim):
		return false
	sim.sortie_paused = not sim.sortie_paused
	if is_instance_valid(sim.ship):
		sim.ship.freeze = sim.sortie_paused
	return sim.sortie_paused

static func restart_sortie(sim: PlanetarySimulation) -> bool:
	if sim == null or not is_instance_valid(sim) or not sim.is_setup:
		return false
	sim.sortie_paused = false
	if is_instance_valid(sim.planet_manager):
		var target_center := Vector3(0.0, -(sim.planet_manager.planet_radius + sim.initial_altitude), 0.0)
		var shift: Vector3 = sim.planet_manager.planet_center_offset - target_center
		if shift != Vector3.ZERO and is_instance_valid(sim.floating_origin):
			sim.floating_origin.rebase(shift)
	if is_instance_valid(sim.floating_origin):
		sim.floating_origin.accumulated_offset = Vector3.ZERO
		sim.floating_origin.origin_sector = Vector3i.ZERO
		sim.floating_origin.origin_local = Vector3.ZERO
	if is_instance_valid(sim.ship):
		sim.ship.freeze = false
		sim.ship.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
		sim.ship.linear_velocity = Vector3.ZERO; sim.ship.angular_velocity = Vector3.ZERO
		sim.ship.thrust_input = Vector3.ZERO; sim.ship.torque_input = Vector3.ZERO
		sim.ship.thrust_cutoff = false
		if sim.ship.is_inside_tree():
			var rid: RID = sim.ship.get_rid()
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, sim.ship.global_transform)
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	if is_instance_valid(sim.target_pool): sim.target_pool.clear()
	if is_instance_valid(sim.projectile_pool): sim.projectile_pool.clear()
	if is_instance_valid(sim.impact_pool): sim.impact_pool.clear()
	if is_instance_valid(sim.weapon_system): sim.weapon_system.locked_target_id = -1
	if is_instance_valid(sim.guidance): sim.guidance.set_mode(FlightGuidanceSystem.MODE_MANUAL)
	if sim.encounter_director != null:
		var dir: EncounterDirector = sim.encounter_director
		if is_instance_valid(dir.thermal): dir.thermal.reset()
		if is_instance_valid(dir.recorder): dir.recorder.clear()
		if is_instance_valid(dir.waypoints): dir.waypoints.clear()
		dir.combat_score = 0; dir.wave_counter = 0; dir.elapsed_time = 0.0
	activate_live_sortie(sim)
	if sim.telemetry != null: sim.telemetry.sample(sim, null)
	if is_instance_valid(sim.hud): sim.hud.update_hud(sim)
	return true
