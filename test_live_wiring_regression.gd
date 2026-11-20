extends SceneTree

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, condition: bool) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("FAIL: ", label)

func _make_sim() -> PlanetarySimulation:
	var sim: PlanetarySimulation = load("res://main.tscn").instantiate()
	sim.auto_step = false
	sim.synchronous_streaming = true
	get_root().add_child(sim)
	return sim

func _dispose(sim: PlanetarySimulation) -> void:
	sim.destroy()
	get_root().remove_child(sim)
	sim.free()

func _run() -> void:
	await process_frame
	_test_governor_single_owner()
	_test_rewind_contract()
	_test_touch_six_dof()
	_test_landing_contact()
	_test_render_governor_adaptation()
	print("LIVE WIRING REGRESSION SUMMARY")
	print("  Total Assertions:   %d" % total_assertions)
	print("  Passed Assertions:  %d" % passed_assertions)
	print("  Failed Assertions:  %d" % failed_assertions)
	quit(0 if failed_assertions == 0 else 1)

func _test_governor_single_owner() -> void:
	var sim: PlanetarySimulation = _make_sim()
	sim.ship.process_user_input = false
	sim.ship.freeze = true
	sim.floating_origin.rebase_threshold = 1.0e12
	sim.planet_manager.max_lod = 1
	sim.encounter_director.governor.reset(2.0)
	for tick in range(120):
		sim.step_simulation(1.0 / 120.0)
	_check("manual simulation does not silently sample nominal frame time",
		is_equal_approx(sim.encounter_director.governor.ema_frame_ms, 8.0))
	_dispose(sim)

func _test_rewind_contract() -> void:
	var sim: PlanetarySimulation = _make_sim()
	var director: EncounterDirector = sim.encounter_director
	director.propellant.enabled = true
	director.propellant.propellant_mass = 600.0
	director.mission.stage = MissionScenarioRunner.STAGE_ORBITAL_INTERCEPT
	director.recorder.record_snapshot(Vector3(100.0, 0.0, 0.0), Vector3.ONE,
		1.0, 300.0, 80.0, FlightGuidanceSystem.MODE_SAS_HOLD)
	director.propellant.propellant_mass = 100.0
	director.mission.stage = MissionScenarioRunner.STAGE_FAILED
	_check("rewind restores fuel", LiveSortieBootstrap.trigger_rewind(sim)
		and is_equal_approx(director.propellant.propellant_mass, 600.0))
	_check("rewind restores mission stage",
		director.mission.stage == MissionScenarioRunner.STAGE_ORBITAL_INTERCEPT)
	_dispose(sim)

func _test_touch_six_dof() -> void:
	var controller: MobileTouchController = MobileTouchController.new()
	controller.enabled = true
	controller.set_virtual_sticks(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0)
	_check("controller supports heave and roll registers",
		controller.thrust_output.y > 0.0 and controller.torque_output.z > 0.0)
	var viewport_size: Vector2 = Vector2(1920.0, 1080.0)
	var heave_origin: Vector2 = MobileTouchLayout.heave_rect(viewport_size).get_center()
	controller.overlay.handle_touch_point(true, 2, heave_origin, viewport_size, controller)
	controller.overlay.handle_drag_point(2, heave_origin + Vector2(0.0, -90.0), controller)
	_check("touch gestures command heave", controller.thrust_output.y > 0.0)
	var roll_origin: Vector2 = MobileTouchLayout.roll_rect(viewport_size).get_center()
	controller.overlay.handle_touch_point(true, 3, roll_origin, viewport_size, controller)
	controller.overlay.handle_drag_point(3, roll_origin + Vector2(0.0, -90.0), controller)
	_check("touch gestures preserve heave while commanding roll",
		controller.thrust_output.y > 0.0 and controller.torque_output.z > 0.0)
	controller.overlay.handle_touch_point(false, 2, heave_origin, viewport_size, controller)
	_check("heave release preserves roll",
		is_zero_approx(controller.thrust_output.y) and controller.torque_output.z > 0.0)
	controller.overlay.handle_touch_point(false, 3, roll_origin, viewport_size, controller)
	_check("final control release disables touch", not controller.enabled)

func _test_landing_contact() -> void:
	var sim: PlanetarySimulation = _make_sim()
	var director: EncounterDirector = sim.encounter_director
	director.mission.stage = MissionScenarioRunner.STAGE_SOFT_LANDING
	sim.telemetry.radar_altitude_agl = 20.0
	sim.telemetry.total_speed = 4.0
	director.landing_gear.weight_on_wheels = false
	director.mission.step_mission(1.0 / 120.0, sim, director)
	_check("airborne ship cannot complete landing mission",
		director.mission.stage != MissionScenarioRunner.STAGE_COMPLETED)
	_dispose(sim)

func _test_render_governor_adaptation() -> void:
	var sim: PlanetarySimulation = _make_sim()
	var governor: FrameBudgetGovernor = sim.encounter_director.governor
	governor.reset(2.0)
	for frame in range(20):
		sim.sample_render_frame(16.0)
	_check("render overload lowers detail", governor.recommended_split_scale < 2.0)
	var overloaded_scale: float = governor.recommended_split_scale
	for frame in range(40):
		sim.sample_render_frame(4.0)
	_check("render recovery raises detail within bounds",
		governor.recommended_split_scale > overloaded_scale
		and governor.recommended_split_scale <= FrameBudgetGovernor.MAX_SPLIT_SCALE)
	_dispose(sim)
