class_name GaitRules
extends RefCounted
## Walk and crouch pose maths for the player's body (design §4). Pure functions, unit-tested.
## Phase is in radians; one full cycle (TAU) is a left and a right step, as in WeaponSwayRules.


## Phase after delta seconds: PI per stride (one step), so the feet land with the footsteps.
static func advance_phase(phase: float, ground_speed: float, stride_m: float, delta: float) -> float:
	return fmod(phase + ground_speed * delta / maxf(stride_m, 0.01) * PI, TAU)


## Half the distance a foot travels back and forth. The stance foot then moves back at ground speed
## in mid-stance, so it does not slide on the floor.
static func foot_amplitude_m(stride_m: float, max_m: float) -> float:
	return minf(stride_m / PI, max_m)


## Foot position along the walking direction (x, metres, forward positive) and height (y, metres)
## for one foot. The foot swings forward and lifts while sin(phase) > 0, then pushes back on the floor.
static func foot_offset(phase: float, amplitude_m: float, lift_m: float) -> Vector2:
	return Vector2(-cos(phase) * amplitude_m, maxf(sin(phase), 0.0) * lift_m)


## Pelvis height change (metres): lowest when both feet are on the floor, highest at mid-stance.
static func pelvis_offset_m(phase: float, bob_m: float) -> float:
	return -cos(phase * 2.0) * bob_m * 0.5 - bob_m * 0.5


## 0 standing, 1 fully crouched, from the current eye height.
static func crouch_amount(eye_height: float, stand_eye_height: float, crouch_eye_height: float) -> float:
	var span: float = stand_eye_height - crouch_eye_height
	if span <= 0.0001:
		return 0.0
	return clampf((stand_eye_height - eye_height) / span, 0.0, 1.0)
