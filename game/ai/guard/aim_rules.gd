class_name AimRules
extends RefCounted
## How well a guard aims (design §7.4): wild at the start of a fight, settling over a few seconds,
## and worse against a moving target.


## Aim error as a cone half-angle in degrees.
static func error_deg(profile: GuardProfile, engaged_seconds: float, target_speed: float) -> float:
	var t: float = clampf(engaged_seconds / maxf(profile.aim_settle_s, 0.001), 0.0, 1.0)
	var error: float = lerpf(profile.aim_error_start_deg, profile.aim_error_min_deg, t)
	if target_speed > PerceptionRules.STILL_SPEED:
		error *= profile.moving_target_error_mult
	return error
