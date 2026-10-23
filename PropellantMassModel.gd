class_name PropellantMassModel
extends RefCounted

## Zero-allocation Tsiolkovsky propellant flow and variable wet-mass model.

const STANDARD_GRAVITY: float = 9.80665

var enabled: bool = false
var dry_mass: float = 1000.0
var max_propellant_mass: float = 600.0
var propellant_mass: float = 600.0
var specific_impulse_s: float = 380.0
var fuel_depleted: bool = false
var mass_flow_rate: float = 0.0

func reset(ship: SpaceshipController = null) -> void:
	propellant_mass = max_propellant_mass
	fuel_depleted = false
	mass_flow_rate = 0.0
	if is_instance_valid(ship):
		ship.thrust_cutoff = false

func get_wet_mass() -> float:
	return maxf(dry_mass, 1.0) + maxf(propellant_mass, 0.0)

func get_fuel_fraction() -> float:
	return clampf(propellant_mass / maxf(max_propellant_mass, 0.001), 0.0, 1.0)

func get_remaining_delta_v() -> float:
	var wet: float = get_wet_mass()
	var dry: float = maxf(dry_mass, 1.0)
	if wet <= dry:
		return 0.0
	return specific_impulse_s * STANDARD_GRAVITY * log(wet / dry)

func step_propellant(delta: float, ship: SpaceshipController) -> float:
	if not is_instance_valid(ship):
		return get_wet_mass()
	if not enabled:
		mass_flow_rate = 0.0
		ship.thrust_cutoff = false
		return ship.mass
	var dt: float = maxf(delta, 0.0)
	if propellant_mass <= 0.0:
		propellant_mass = 0.0
		fuel_depleted = true
		mass_flow_rate = 0.0
		ship.thrust_cutoff = true
		ship.set_thrust_input(Vector3.ZERO)
		ship.mass = maxf(dry_mass, 1.0)
		return ship.mass
	var tx: float = absf(ship.thrust_input.x) * ship.strafe_thrust
	var ty: float = absf(ship.thrust_input.y) * ship.vertical_thrust
	var tz: float = absf(ship.thrust_input.z) * (
		ship.forward_thrust if ship.thrust_input.z >= 0.0 else ship.reverse_thrust
	)
	var thrust_mag: float = sqrt(tx * tx + ty * ty + tz * tz)
	var v_e: float = maxf(specific_impulse_s * STANDARD_GRAVITY, 1.0)
	mass_flow_rate = thrust_mag / v_e
	propellant_mass = maxf(propellant_mass - mass_flow_rate * dt, 0.0)
	fuel_depleted = propellant_mass <= 0.0
	ship.thrust_cutoff = fuel_depleted
	if fuel_depleted:
		ship.set_thrust_input(Vector3.ZERO)
	ship.mass = get_wet_mass()
	return ship.mass
