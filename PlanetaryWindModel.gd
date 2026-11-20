class_name PlanetaryWindModel
extends RefCounted

## Deterministic altitude-banded jetstream and turbulence sampler.

var enabled: bool = false
var base_jetstream_speed: float = 45.0
var jetstream_altitude: float = 3500.0
var jetstream_half_width: float = 2500.0
var turbulence_amplitude: float = 8.0
var turbulence_frequency: float = 1.7
var elapsed_time: float = 0.0
var current_wind_velocity: Vector3 = Vector3.ZERO
var current_wind_speed: float = 0.0

func reset() -> void:
	elapsed_time = 0.0
	current_wind_velocity = Vector3.ZERO
	current_wind_speed = 0.0

func sample_wind(
	delta: float,
	ship_pos: Vector3,
	planet_center: Vector3,
	planet_radius: float,
	atmosphere_ceiling: float
) -> Vector3:
	elapsed_time += maxf(delta, 0.0)
	if not enabled:
		current_wind_velocity = Vector3.ZERO
		current_wind_speed = 0.0
		return Vector3.ZERO

	var radial: Vector3 = ship_pos - planet_center
	var r_len: float = radial.length()
	var altitude: float = r_len - planet_radius
	if altitude >= atmosphere_ceiling or r_len < 1e-6:
		current_wind_velocity = Vector3.ZERO
		current_wind_speed = 0.0
		return Vector3.ZERO

	var radial_up: Vector3 = radial / r_len
	var ref_axis: Vector3 = Vector3.BACK if absf(radial_up.z) < 0.99 else Vector3.RIGHT
	var zonal: Vector3 = ref_axis.cross(radial_up).normalized()
	var meridional: Vector3 = radial_up.cross(zonal).normalized()

	var band_norm: float = (altitude - jetstream_altitude) / maxf(jetstream_half_width, 1.0)
	var env: float = exp(-0.5 * band_norm * band_norm) * clampf(
		1.0 - maxf(altitude, 0.0) / maxf(atmosphere_ceiling, 1.0), 0.0, 1.0
	)
	var gust: float = sin(
		elapsed_time * turbulence_frequency + radial_up.x * 3.1 + radial_up.z * 2.3
	) * turbulence_amplitude * env

	current_wind_velocity = zonal * (base_jetstream_speed * env) + meridional * gust
	current_wind_speed = current_wind_velocity.length()
	return current_wind_velocity
