class_name WeaponHeatCapacitor
extends RefCounted

## Fixed-state weapon thermal model with an opt-in fire-rate and overheat gate.

var enabled: bool = false
var heat: float = 0.0
var max_heat: float = 100.0
var heat_per_shot: float = 18.0
var cooling_rate: float = 28.0
var fire_interval: float = 0.12
var cooldown_remaining: float = 0.0
var overheated: bool = false
var overheat_clear_ratio: float = 0.5
var shots_fired: int = 0

func reset() -> void:
	heat = 0.0
	cooldown_remaining = 0.0
	overheated = false
	shots_fired = 0

func get_normalized_heat() -> float:
	return clampf(heat / maxf(max_heat, 0.001), 0.0, 1.0)

func can_fire() -> bool:
	if not enabled:
		return true
	return not overheated and cooldown_remaining <= 0.0 and heat < max_heat

func consume_shot() -> bool:
	if not can_fire():
		return false
	shots_fired += 1
	if not enabled:
		return true
	cooldown_remaining = fire_interval
	heat = minf(heat + heat_per_shot, max_heat)
	if heat >= max_heat:
		overheated = true
	return true

func step_capacitor(delta: float) -> void:
	var dt: float = maxf(delta, 0.0)
	cooldown_remaining = maxf(cooldown_remaining - dt, 0.0)
	heat = maxf(heat - cooling_rate * dt, 0.0)
	if overheated and heat <= max_heat * overheat_clear_ratio:
		overheated = false
