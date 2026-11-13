class_name ViewmodelAnimationRules
extends RefCounted
## Pure helpers for playing a viewmodel's baked animations in step with the weapon logic.

const MIN_SPEED: float = 0.25
const MAX_SPEED: float = 4.0


## Playback speed that makes an animation of length_s last duration_s. duration_s <= 0 means natural speed.
static func speed_for(length_s: float, duration_s: float) -> float:
	if length_s <= 0.0 or duration_s <= 0.0:
		return 1.0
	return clampf(length_s / duration_s, MIN_SPEED, MAX_SPEED)
