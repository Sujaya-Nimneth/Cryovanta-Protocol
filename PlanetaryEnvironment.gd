class_name PlanetaryEnvironment
extends Node3D

## Surface-to-vacuum lighting, fog, and sky environment with fixed resources.

const FOG_BASE_DENSITY: float = 0.00012
const FOG_SURFACE_MULTIPLIER: float = 2.2
const SKY_SURFACE_ENERGY: float = 1.35
const SKY_VACUUM_ENERGY: float = 2.4

var sun_light: DirectionalLight3D = null
var world_environment: WorldEnvironment = null
var environment: Environment = null
var sky_material: ProceduralSkyMaterial = null
var current_atmosphere_factor: float = 0.0
var current_fog_density: float = 0.0

var _sky: Sky = null

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

func update_environment(
	vessel_pos: Vector3,
	planet_center: Vector3,
	planet_radius: float,
	atmosphere_ceiling: float,
	surface_density: float = 1.225
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
