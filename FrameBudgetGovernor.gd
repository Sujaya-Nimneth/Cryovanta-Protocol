class_name FrameBudgetGovernor
extends RefCounted

## Zero-allocation 120 FPS frame-budget governor for adaptive quadtree detail.

const TARGET_FRAME_MS: float = 8.333333
const MIN_SPLIT_SCALE: float = 1.0
const MAX_SPLIT_SCALE: float = 4.0

var ema_frame_ms: float = 8.0
var ema_alpha: float = 0.15
var recommended_split_scale: float = 2.0
var over_budget_streak: int = 0
var under_budget_streak: int = 0
var enabled: bool = true

func reset(initial_split_scale: float = 2.0) -> void:
	ema_frame_ms = 8.0
	recommended_split_scale = clampf(initial_split_scale, MIN_SPLIT_SCALE, MAX_SPLIT_SCALE)
	over_budget_streak = 0
	under_budget_streak = 0

func sample_frame_time(frame_ms: float, planet_manager: PlanetManager = null) -> float:
	if not enabled:
		return recommended_split_scale
	ema_frame_ms = lerpf(ema_frame_ms, maxf(frame_ms, 0.0), ema_alpha)
	if ema_frame_ms > TARGET_FRAME_MS * 1.05:
		over_budget_streak += 1
		under_budget_streak = 0
		if over_budget_streak >= 4:
			recommended_split_scale = maxf(MIN_SPLIT_SCALE, recommended_split_scale - 0.1)
	elif ema_frame_ms < TARGET_FRAME_MS * 0.80:
		under_budget_streak += 1
		over_budget_streak = 0
		if under_budget_streak >= 8:
			recommended_split_scale = minf(MAX_SPLIT_SCALE, recommended_split_scale + 0.05)
	else:
		over_budget_streak = 0
		under_budget_streak = 0
	if is_instance_valid(planet_manager):
		planet_manager.lod_split_scale = recommended_split_scale
	return recommended_split_scale
