class_name MovementRules
extends RefCounted
## Pure movement rules (design §4), kept free of scene dependencies so they are unit-tested directly.

## Sprint needs mostly-forward input.
const SPRINT_MIN_FORWARD: float = 0.5


static func target_speed(settings: PlayerMovementSettings, crouched: bool, sprinting: bool, aiming: bool) -> float:
	var speed: float = settings.walk_speed
	if crouched:
		speed = settings.crouch_speed
	elif sprinting:
		speed = settings.sprint_speed
	if aiming:
		speed *= settings.aim_speed_multiplier
	return speed


static func can_sprint(move: Vector2, sprint_held: bool, crouched: bool) -> bool:
	return sprint_held and not crouched and move.y >= SPRINT_MIN_FORWARD


## Acceleration to use this tick: full when steering on the ground, braking when there is no input,
## reduced in the air.
static func acceleration(settings: PlayerMovementSettings, on_floor: bool, has_input: bool) -> float:
	if not on_floor:
		return settings.ground_acceleration * settings.air_control
	return settings.ground_acceleration if has_input else settings.ground_deceleration
