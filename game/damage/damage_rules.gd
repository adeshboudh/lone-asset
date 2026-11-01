class_name DamageRules
extends RefCounted
## Pure damage maths (design §6).

const FALL_SAFE_HEIGHT_M: float = 4.0
const FALL_LETHAL_HEIGHT_M: float = 10.0


## Linear from 0 at the safe height to max_health at the lethal height.
static func fall_damage(height: float, max_health: float) -> float:
	var t: float = inverse_lerp(FALL_SAFE_HEIGHT_M, FALL_LETHAL_HEIGHT_M, height)
	return clampf(t, 0.0, 1.0) * max_health
