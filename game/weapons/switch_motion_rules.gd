class_name SwitchMotionRules
extends RefCounted
## Pure rules of the weapon switch. A weight of 1 is the fully lowered pose, 0 the weapon at rest, below 0 the
## small overshoot of the draw. Weapon multiplies SwitchMotionSettings.lowered_offset and lowered_rotation_deg by it.

## The draw is a damped spring that decays to 1 % of its start at the draw time.
const SETTLE_NEPER: float = 4.6


## Putting away: progress 0..1 in, weight 0..1 out, easing in and out (slow start, fast middle, soft finish).
static func holster_weight(progress: float) -> float:
	var t: float = clampf(progress, 0.0, 1.0)
	return 0.5 - 0.5 * cos(PI * t)


## Raising: seconds since the draw began in, weight out. Starts at 1 (lowered), swings through the rest pose,
## overshoots slightly past it and settles to 0 at draw_time_s (the step response of an underdamped spring).
static func draw_weight(elapsed_s: float, draw_time_s: float, damping: float) -> float:
	if elapsed_s >= draw_time_s:
		return 0.0
	var t: float = maxf(elapsed_s, 0.0)
	var zeta: float = clampf(damping, 0.05, 0.99)
	var omega: float = SETTLE_NEPER / (zeta * draw_time_s)
	var omega_d: float = omega * sqrt(1.0 - zeta * zeta)
	var decay: float = exp(-zeta * omega * t)
	var step: float = 1.0 - decay * (cos(omega_d * t) + zeta * omega / omega_d * sin(omega_d * t))
	return 1.0 - step


## Movement weight: the holster plus the draw (only one of them is away from 0 at a time).
static func position_weight(holster_progress: float, draw_elapsed_s: float, s: SwitchMotionSettings) -> float:
	return holster_weight(holster_progress) + draw_weight(draw_elapsed_s, s.draw_time_s, s.draw_damping)


## Rotation weight: the same, with the draw trailing the movement.
static func rotation_weight(holster_progress: float, draw_elapsed_s: float, s: SwitchMotionSettings) -> float:
	return holster_weight(holster_progress) + draw_weight(maxf(draw_elapsed_s - s.draw_rotation_lag_s, 0.0), s.draw_time_s, s.draw_damping)
