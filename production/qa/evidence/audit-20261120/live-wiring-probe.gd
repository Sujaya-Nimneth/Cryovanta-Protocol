extends SceneTree

const DT: float = 1.0 / 120.0
var failures: int = 0

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _make_sim(synchronous: bool) -> PlanetarySimulation:
	var packed: PackedScene = load("res://main.tscn")
	var sim: PlanetarySimulation = packed.instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = synchronous
	get_root().add_child(sim)
	return sim

func _dispose(sim: PlanetarySimulation) -> void:
	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

func _run() -> void:
	await process_frame
	_probe_governor()
	await _probe_async_memory()
	_probe_rewind()
	_probe_touch_axes()
	_probe_landing()
	print("PROBE_FAILURES=", failures)
	quit(0 if failures == 0 else 1)

func _probe_governor() -> void:
	var sim: PlanetarySimulation = _make_sim(true)
	sim.ship.process_user_input = false
	sim.ship.freeze = true
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.encounter_director.governor.reset(2.0)
	for tick in range(300):
		sim.step_simulation(DT)
	print("GOVERNOR manual_step ema_ms=", sim.encounter_director.governor.ema_frame_ms,
		" split_scale=", sim.encounter_director.governor.recommended_split_scale)
	_check("manual 120 Hz steps keep governor near 8.333 ms",
		absf(sim.encounter_director.governor.ema_frame_ms - 8.333333) < 0.05)
	_check("manual 120 Hz steps do not inflate LOD scale",
		is_equal_approx(sim.encounter_director.governor.recommended_split_scale, 2.0))
	_dispose(sim)

func _probe_async_memory() -> void:
	var sim: PlanetarySimulation = _make_sim(false)
	sim.ship.process_user_input = false
	sim.ship.freeze = true
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 5
	sim.encounter_director.governor.enabled = false
	for tick in range(3000):
		sim.step_simulation(DT)
		OS.delay_usec(100)
	var guard: int = 0
	while sim.planet_streamer.pending_jobs > 0 and guard < 10000:
		sim.planet_streamer.task_scheduler.poll()
		OS.delay_usec(100)
		guard += 1
	var before: int = OS.get_static_memory_usage()
	var visuals_before: int = sim.planet_streamer.get_active_visual_count()
	for tick in range(6000):
		sim.step_simulation(DT)
		OS.delay_usec(100)
	var after: int = OS.get_static_memory_usage()
	print("ASYNC visuals=", visuals_before, "->", sim.planet_streamer.get_active_visual_count(),
		" pending=", sim.planet_streamer.pending_jobs,
		" staging_free=", sim.planet_streamer.staging_free.size(),
		" static_delta=", after - before)
	_check("async steady state has no pending jobs", sim.planet_streamer.pending_jobs == 0)
	_check("async steady state returns all staging slots", sim.planet_streamer.staging_free.size() == 64)
	_check("async steady state has zero static memory growth", after - before <= 0)
	_dispose(sim)

func _probe_rewind() -> void:
	var sim: PlanetarySimulation = _make_sim(true)
	var director: EncounterDirector = sim.encounter_director
	director.recorder.recording_enabled = true
	director.propellant.enabled = true
	director.propellant.propellant_mass = 600.0
	director.mission.stage = MissionScenarioRunner.STAGE_ORBITAL_INTERCEPT
	director.recorder.record_snapshot(Vector3(100.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		1.0, 300.0, 80.0, FlightGuidanceSystem.MODE_SAS_HOLD)
	sim.ship.global_position = Vector3(500.0, 0.0, 0.0)
	sim.ship.linear_velocity = Vector3(9.0, 0.0, 0.0)
	director.thermal.hull_integrity = 20.0
	director.propellant.propellant_mass = 100.0
	director.mission.stage = MissionScenarioRunner.STAGE_FAILED
	var restored: bool = LiveSortieBootstrap.trigger_rewind(sim)
	print("REWIND restored=", restored, " pos=", sim.ship.global_position,
		" hull=", director.thermal.hull_integrity,
		" fuel=", director.propellant.propellant_mass,
		" mission_stage=", director.mission.stage)
	_check("rewind restores ship position", restored and sim.ship.global_position.distance_to(Vector3(100.0, 0.0, 0.0)) < 0.001)
	_check("rewind restores hull", is_equal_approx(director.thermal.hull_integrity, 80.0))
	_check("rewind restores fuel", is_equal_approx(director.propellant.propellant_mass, 600.0))
	_check("rewind restores mission stage", director.mission.stage == MissionScenarioRunner.STAGE_ORBITAL_INTERCEPT)
	_dispose(sim)

func _probe_touch_axes() -> void:
	var controller: MobileTouchController = MobileTouchController.new()
	var overlay: MobileTouchOverlay = controller.overlay
	var viewport: Vector2 = Vector2(1920.0, 1080.0)
	overlay.handle_touch_point(true, 0, Vector2(300.0, 700.0), viewport, controller)
	overlay.handle_drag_point(0, Vector2(300.0, 610.0), controller)
	overlay.handle_touch_point(true, 1, Vector2(1500.0, 700.0), viewport, controller)
	overlay.handle_drag_point(1, Vector2(1590.0, 610.0), controller)
	print("TOUCH thrust=", controller.thrust_output, " torque=", controller.torque_output)
	_check("touch overlay can command vertical thrust", absf(controller.thrust_output.y) > 0.0)
	_check("touch overlay can command roll torque", absf(controller.torque_output.z) > 0.0)

func _probe_landing() -> void:
	var sim: PlanetarySimulation = _make_sim(true)
	var director: EncounterDirector = sim.encounter_director
	director.mission.stage = MissionScenarioRunner.STAGE_SOFT_LANDING
	sim.telemetry.radar_altitude_agl = 20.0
	sim.telemetry.total_speed = 4.0
	director.landing_gear.weight_on_wheels = false
	director.mission.step_mission(DT, sim, director)
	_check("mission completion requires weight-on-wheels",
		director.mission.stage != MissionScenarioRunner.STAGE_COMPLETED)
	var gear: LandingGearModel = LandingGearModel.new()
	gear.enabled = true
	gear.deploy_progress = 1.0
	var thermal: ThermalStructuralModel = ThermalStructuralModel.new()
	gear.step_gear(DT, 3.0, -20.0, null, thermal)
	print("LANDING hard_touchdown_single_tick_hull=", thermal.hull_integrity)
	_dispose(sim)
