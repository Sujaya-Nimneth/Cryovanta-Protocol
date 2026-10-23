class_name FlightRecorderRingBuffer
extends RefCounted

## Fixed 64-slot black-box recorder for rebase-aware flight snapshots.

const CAPACITY: int = 64

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

func _init() -> void:
	positions.resize(CAPACITY)
	velocities.resize(CAPACITY)
	g_loads.resize(CAPACITY)
	temperatures_k.resize(CAPACITY)
	hull_integrities.resize(CAPACITY)
	guidance_modes.resize(CAPACITY)
	clear()

func clear() -> void:
	head = 0
	count = 0
	total_recorded = 0
	time_since_last_sample = 0.0
	var slot: int = 0
	while slot < CAPACITY:
		positions[slot] = Vector3.ZERO
		velocities[slot] = Vector3.ZERO
		g_loads[slot] = 0.0
		temperatures_k[slot] = 0.0
		hull_integrities[slot] = 0.0
		guidance_modes[slot] = 0
		slot += 1

func record_snapshot(
	pos: Vector3,
	vel: Vector3,
	g_load: float,
	temp_k: float,
	hull: float,
	mode: int
) -> int:
	var slot: int = head
	positions[slot] = pos
	velocities[slot] = vel
	g_loads[slot] = g_load
	temperatures_k[slot] = temp_k
	hull_integrities[slot] = hull
	guidance_modes[slot] = clampi(mode, 0, 8)
	head = (head + 1) % CAPACITY
	count = mini(count + 1, CAPACITY)
	total_recorded += 1
	return slot

func step_recorder(
	delta: float,
	ship_pos: Vector3,
	ship_vel: Vector3,
	telemetry: SimulationTelemetry,
	mode: int
) -> bool:
	if not recording_enabled or telemetry == null:
		return false
	time_since_last_sample += maxf(delta, 0.0)
	if time_since_last_sample < sample_interval:
		return false
	time_since_last_sample = fmod(time_since_last_sample, maxf(sample_interval, 0.001))
	record_snapshot(
		ship_pos,
		ship_vel,
		telemetry.g_load,
		telemetry.surface_temperature_k,
		telemetry.hull_integrity,
		mode
	)
	return true

func get_latest_slot() -> int:
	if count == 0:
		return -1
	return (head - 1 + CAPACITY) % CAPACITY

func restore_snapshot(
	slot: int,
	ship: SpaceshipController,
	thermal: ThermalStructuralModel = null,
	guidance: FlightGuidanceSystem = null
) -> bool:
	if slot < 0 or slot >= count or slot >= CAPACITY or not is_instance_valid(ship):
		return false
	if ship.is_inside_tree():
		ship.global_position = positions[slot]
	else:
		ship.position = positions[slot]
	ship.linear_velocity = velocities[slot]
	if ship.is_inside_tree():
		PhysicsServer3D.body_set_state(
			ship.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, ship.global_transform
		)
		PhysicsServer3D.body_set_state(
			ship.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, velocities[slot]
		)
	if is_instance_valid(thermal):
		thermal.surface_temperature_k = temperatures_k[slot]
		thermal.hull_integrity = hull_integrities[slot]
	if is_instance_valid(guidance):
		guidance.set_mode(int(guidance_modes[slot]))
	return true

func rebase_origin(offset: Vector3) -> void:
	if offset == Vector3.ZERO or count == 0:
		return
	var slot: int = 0
	while slot < CAPACITY:
		positions[slot] -= offset
		slot += 1
