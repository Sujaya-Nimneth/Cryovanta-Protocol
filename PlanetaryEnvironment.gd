class_name PlanetaryEnvironment
extends Node3D

## Surface-to-vacuum lighting, fog, and sky environment with fixed resources.

const FOG_BASE_DENSITY: float = 0.00012
const FOG_SURFACE_MULTIPLIER: float = 2.2
const SKY_SURFACE_ENERGY: float = 1.35
const SKY_VACUUM_ENERGY: float = 2.4
const AUDIO_SAMPLE_RATE: float = 22050.0

var sun_light: DirectionalLight3D = null
var world_environment: WorldEnvironment = null
var environment: Environment = null
var sky_material: ProceduralSkyMaterial = null
var current_atmosphere_factor: float = 0.0
var current_fog_density: float = 0.0
var audio_enabled: bool = false

var _sky: Sky = null
var _audio_player: AudioStreamPlayer = null
var _audio_stream: AudioStreamGenerator = null
var _audio_playback: AudioStreamGeneratorPlayback = null
var _phase_engine: float = 0.0
var _phase_alert: float = 0.0
var _phase_weapon: float = 0.0
var _weapon_pulse: float = 0.0
var _prev_weapon_heat: float = 0.0
var _alert_timer: float = 0.0

func _init() -> void:
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun_light.light_energy = 1.15
	sun_light.shadow_enabled = true
	add_child(sun_light)

	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.08, 0.18, 0.34)
	sky_material.sky_horizon_color = Color(0.56, 0.72, 0.88)
	sky_material.ground_bottom_color = Color(0.025, 0.04, 0.06)
	sky_material.ground_horizon_color = Color(0.25, 0.34, 0.42)
	sky_material.sky_energy_multiplier = SKY_SURFACE_ENERGY
	_sky = Sky.new()
	_sky.sky_material = sky_material

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = _sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.65
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_color = Color(0.58, 0.72, 0.86)
	environment.fog_density = FOG_BASE_DENSITY * FOG_SURFACE_MULTIPLIER
	environment.fog_sky_affect = 0.8

	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	_init_cockpit_audio()

func _init_cockpit_audio() -> void:
	if DisplayServer.get_name() == "headless":
		audio_enabled = false
		return
	_audio_stream = AudioStreamGenerator.new()
	_audio_stream.mix_rate = AUDIO_SAMPLE_RATE
	_audio_stream.buffer_length = 0.06
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "CockpitAudioSynth"
	_audio_player.stream = _audio_stream
	_audio_player.volume_db = -10.0
	add_child(_audio_player)
	audio_enabled = true

func update_environment(
	vessel_pos: Vector3,
	planet_center: Vector3,
	planet_radius: float,
	atmosphere_ceiling: float,
	surface_density: float = 1.225,
	thrust_norm: float = 0.0,
	alert_level: int = 0,
	weapon_heat: float = 0.0,
	dt: float = 1.0 / 120.0
) -> void:
	var altitude: float = AtmosphereMath.get_altitude(vessel_pos, planet_center, planet_radius)
	current_atmosphere_factor = clampf(
		AtmosphereMath.get_air_density(altitude, atmosphere_ceiling, surface_density)
		/ maxf(surface_density, 0.001),
		0.0,
		1.0
	)
	if altitude >= atmosphere_ceiling:
		current_atmosphere_factor = 0.0
	current_fog_density = FOG_BASE_DENSITY * current_atmosphere_factor
	environment.fog_density = current_fog_density
	environment.fog_enabled = current_fog_density > 0.0
	environment.ambient_light_energy = lerpf(0.22, 0.8, current_atmosphere_factor)
	sky_material.sky_energy_multiplier = lerpf(
		SKY_VACUUM_ENERGY, SKY_SURFACE_ENERGY, current_atmosphere_factor
	)
	sun_light.light_energy = lerpf(1.45, 1.15, current_atmosphere_factor)
	update_cockpit_audio(dt, thrust_norm, alert_level, weapon_heat)

func update_cockpit_audio(dt: float, thrust_norm: float, alert_level: int, weapon_heat: float) -> void:
	if weapon_heat > _prev_weapon_heat + 0.01:
		_weapon_pulse = 1.0
	_prev_weapon_heat = weapon_heat
	_weapon_pulse = maxf(_weapon_pulse - maxf(dt, 0.0) * 6.5, 0.0)
	_alert_timer += maxf(dt, 0.0)
	if not audio_enabled or not is_instance_valid(_audio_player):
		return
	if not _audio_player.playing and _audio_player.is_inside_tree():
		_audio_player.play()
		_audio_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _audio_playback == null:
		return
	var frames: int = mini(_audio_playback.get_frames_available(), 256)
	var eng_freq: float = lerpf(58.0, 145.0, clampf(thrust_norm, 0.0, 1.0))
	var alert_freq: float = 0.0
	if alert_level == 1 and fmod(_alert_timer, 0.5) < 0.2:
		alert_freq = 660.0
	elif alert_level >= 2:
		alert_freq = 1180.0 if fmod(_alert_timer, 0.25) < 0.125 else 880.0
	for _i in range(frames):
		_phase_engine = fposmod(_phase_engine + eng_freq / AUDIO_SAMPLE_RATE, 1.0)
		_phase_alert = fposmod(_phase_alert + alert_freq / AUDIO_SAMPLE_RATE, 1.0)
		_phase_weapon = fposmod(_phase_weapon + lerpf(180.0, 520.0, _weapon_pulse) / AUDIO_SAMPLE_RATE, 1.0)
		var sample: float = synthesize_cockpit_sample(thrust_norm, current_atmosphere_factor, _weapon_pulse, alert_level, alert_freq > 0.0, _phase_engine, _phase_alert, _phase_weapon)
		_audio_playback.push_frame(Vector2(sample, sample))

static func synthesize_cockpit_sample(
	thrust_norm: float, atmosphere_factor: float, weapon_pulse: float,
	alert_level: int, alert_gate: bool, phase_engine: float, phase_alert: float, phase_weapon: float
) -> float:
	var thrust_gain: float = clampf(thrust_norm, 0.0, 1.0) * (0.14 + 0.1 * atmosphere_factor)
	var eng: float = (sin(phase_engine * TAU) * 0.7 + sin(phase_engine * TAU * 2.0) * 0.3) * thrust_gain
	var wpn: float = sin(phase_weapon * TAU) * clampf(weapon_pulse, 0.0, 1.0) * 0.25
	var alrt: float = sin(phase_alert * TAU) * (0.22 if (alert_level > 0 and alert_gate) else 0.0)
	return clampf(eng + wpn + alrt, -0.85, 0.85)
