class_name AtmosphereMath
extends RefCounted

## Pure static mathematical utilities for atmospheric density and aerodynamic drag.
## Complies with rules.md:
## - Script length strictly <= 250 lines
## - Zero runtime heap memory allocations
## - Pure static math decoupled from scene nodes

## Computes Euclidean distance from planet center minus planet radius.
static func get_altitude(vessel_pos: Vector3, planet_pos: Vector3, planet_radius: float) -> float:
	return vessel_pos.distance_to(planet_pos) - planet_radius

## Alias for get_altitude.
static func calculate_altitude(vessel_pos: Vector3, planet_pos: Vector3, planet_radius: float) -> float:
	return get_altitude(vessel_pos, planet_pos, planet_radius)

## Calculates air density rho(h) [kg/m^3].
## Strictly returns 0.0 when altitude >= atmosphere_ceiling.
## When altitude < atmosphere_ceiling, smoothly interpolates to surface density using Hermite smoothstep.
static func get_air_density(altitude: float, atmosphere_ceiling: float, surface_density: float = 1.225) -> float:
	if altitude >= atmosphere_ceiling or atmosphere_ceiling <= 0.0:
		return 0.0
	if altitude <= 0.0:
		return surface_density
	
	var u: float = clampf(altitude / atmosphere_ceiling, 0.0, 1.0)
	# Hermite smoothstep polynomial: C1 continuous, 0 derivative at ceiling & surface
	var factor: float = (1.0 - u) * (1.0 - u) * (1.0 + 2.0 * u)
	return surface_density * factor

## Alias for get_air_density.
static func calculate_density(altitude: float, atmosphere_ceiling: float, surface_density: float = 1.225) -> float:
	return get_air_density(altitude, atmosphere_ceiling, surface_density)

## Calculates aerodynamic drag force vector: F_drag = -0.5 * rho * C_d * A * |v| * v.
## Opposes motion and scales with density and speed squared.
static func calculate_drag_force(
	velocity: Vector3,
	air_density: float,
	drag_coefficient: float = 0.5,
	cross_sectional_area: float = 10.0
) -> Vector3:
	if air_density <= 0.0:
		return Vector3.ZERO
	var speed: float = velocity.length()
	if speed < 1e-9:
		return Vector3.ZERO
	var drag_factor: float = 0.5 * air_density * drag_coefficient * cross_sectional_area * speed
	return -velocity * drag_factor

## Alias for calculate_drag_force.
static func get_drag_force(
	velocity: Vector3,
	air_density: float,
	drag_coefficient: float = 0.5,
	cross_sectional_area: float = 10.0
) -> Vector3:
	return calculate_drag_force(velocity, air_density, drag_coefficient, cross_sectional_area)
