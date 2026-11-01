class_name NoiseRules
extends RefCounted
## Pure noise maths (design §8.2), unit-tested directly.

## Walls beyond this many add no further attenuation.
const MAX_WALLS: int = 3
## Each wall between source and listener halves the radius.
const WALL_FACTOR: float = 0.5
## Below this speed (m/s) the player is not stepping.
const MIN_STEP_SPEED: float = 0.5


static func effective_radius(radius_m: float, walls: int) -> float:
	return radius_m * pow(WALL_FACTOR, mini(maxi(walls, 0), MAX_WALLS))


static func is_heard(distance: float, effective_radius_m: float) -> bool:
	return distance <= effective_radius_m


static func footstep_type(crouched: bool, sprinting: bool) -> StringName:
	if crouched:
		return NoiseEvent.FOOTSTEP_CROUCH
	return NoiseEvent.FOOTSTEP_SPRINT if sprinting else NoiseEvent.FOOTSTEP_WALK
