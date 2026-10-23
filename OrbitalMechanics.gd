class_name OrbitalMechanics
extends RefCounted

## Pure static Keplerian orbital mechanics and fixed-buffer trajectory prediction.
## Every routine is allocation-free and uses the planet's radius-clamped gravity.

static func get_gravitational_parameter(planet_radius: float, surface_gravity: float = 9.81) -> float:
	return surface_gravity * planet_radius * planet_radius

static func get_circular_orbit_speed(
	vessel_pos: Vector3,
	planet_pos: Vector3,
	planet_radius: float,
	surface_gravity: float = 9.81
) -> float:
	var radius: float = maxf(vessel_pos.distance_to(planet_pos), planet_radius)
	return sqrt(get_gravitational_parameter(planet_radius, surface_gravity) / maxf(radius, 0.001))

static func get_escape_speed(
	vessel_pos: Vector3,
	planet_pos: Vector3,
	planet_radius: float,
	surface_gravity: float = 9.81
) -> float:
	var radius: float = maxf(vessel_pos.distance_to(planet_pos), planet_radius)
	return sqrt(
		2.0 * get_gravitational_parameter(planet_radius, surface_gravity) / maxf(radius, 0.001)
	)

static func get_specific_orbital_energy(
	vessel_pos: Vector3,
	velocity: Vector3,
	planet_pos: Vector3,
	planet_radius: float,
	surface_gravity: float = 9.81
) -> float:
	var radius: float = maxf(vessel_pos.distance_to(planet_pos), planet_radius)
	var mu: float = get_gravitational_parameter(planet_radius, surface_gravity)
	return 0.5 * velocity.length_squared() - mu / maxf(radius, 0.001)

static func get_eccentricity_vector(
	vessel_pos: Vector3,
	velocity: Vector3,
	planet_pos: Vector3,
	planet_radius: float,
	surface_gravity: float = 9.81
) -> Vector3:
	var mu: float = get_gravitational_parameter(planet_radius, surface_gravity)
	if mu <= 0.0:
		return Vector3.ZERO
	var r_vec: Vector3 = vessel_pos - planet_pos
	var h_vec: Vector3 = r_vec.cross(velocity)
	return velocity.cross(h_vec) / mu - r_vec.normalized()

static func get_apsides_altitudes(
	vessel_pos: Vector3,
	velocity: Vector3,
	planet_pos: Vector3,
	planet_radius: float,
	surface_gravity: float = 9.81
) -> Vector2:
	var mu: float = get_gravitational_parameter(planet_radius, surface_gravity)
	var r_vec: Vector3 = vessel_pos - planet_pos
	var h2: float = r_vec.cross(velocity).length_squared()
	var eccentricity: float = get_eccentricity_vector(
		vessel_pos, velocity, planet_pos, planet_radius, surface_gravity
	).length()
	var energy: float = get_specific_orbital_energy(
		vessel_pos, velocity, planet_pos, planet_radius, surface_gravity
	)
	var semi_latus_rectum: float = h2 / maxf(mu, 0.001)
	var periapsis: float = semi_latus_rectum / maxf(1.0 + eccentricity, 0.001) - planet_radius
	if eccentricity >= 1.0 or energy >= 0.0:
		return Vector2(periapsis, INF)
	return Vector2(
		periapsis,
		semi_latus_rectum / maxf(1.0 - eccentricity, 0.001) - planet_radius
	)

static func calculate_circularization_dv(
	vessel_pos: Vector3,
	velocity: Vector3,
	planet_pos: Vector3,
	planet_radius: float,
	surface_gravity: float = 9.81
) -> Vector3:
	var r_vec: Vector3 = vessel_pos - planet_pos
	var radial: Vector3 = r_vec.normalized()
	var prograde: Vector3 = velocity - radial * velocity.dot(radial)
	if prograde.length_squared() < 1e-12:
		var ref: Vector3 = Vector3.UP if absf(radial.y) < 0.99 else Vector3.RIGHT
		prograde = radial.cross(ref).normalized()
	if prograde.length_squared() < 1e-12:
		return Vector3.ZERO
	var target_speed: float = get_circular_orbit_speed(
		vessel_pos, planet_pos, planet_radius, surface_gravity
	)
	return prograde.normalized() * target_speed - velocity

static func predict_trajectory(
	vessel_pos: Vector3,
	velocity: Vector3,
	planet_pos: Vector3,
	planet_radius: float,
	surface_gravity: float,
	dt: float,
	steps: int,
	out_points: PackedVector3Array
) -> int:
	var count: int = mini(maxi(steps, 0), out_points.size())
	var position: Vector3 = vessel_pos
	var velocity_step: Vector3 = velocity
	var gravity: Vector3 = AtmosphereMath.calculate_gravity_acceleration(
		position, planet_pos, planet_radius, surface_gravity
	)
	var next_pos: Vector3 = Vector3.ZERO
	var next_gravity: Vector3 = Vector3.ZERO
	for i in range(count):
		next_pos = position + velocity_step * dt + gravity * (0.5 * dt * dt)
		next_gravity = AtmosphereMath.calculate_gravity_acceleration(
			next_pos, planet_pos, planet_radius, surface_gravity
		)
		velocity_step += 0.5 * (gravity + next_gravity) * dt
		position = next_pos
		gravity = next_gravity
		if AtmosphereMath.get_altitude(next_pos, planet_pos, planet_radius) <= 0.0:
			return i
		out_points[i] = next_pos
	return count
