class_name AdsRules
extends RefCounted
## Look of the hip-to-aim move (design §5.2). aim_blend stays linear for gameplay (spread, recoil);
## the viewmodel and the FOV follow a damped spring toward "aiming" or "not aiming" (spring_step), so the move
## starts and ends gently, keeps its speed when the button is released half-way, and settles past the sights.
## visual_blend is the older fixed curve over the linear blend, kept for reference and its tests.

## Longest step the spring takes at once; longer frames are split so it stays stable.
const MAX_STEP_S: float = 1.0 / 120.0
## Angular frequency times the move time: a critically damped spring covers 95 % of the way in 4.74 / omega.
const REACH_95: float = 4.74


## Viewmodel blend for a linear aim_blend (0-1). Eases in and out, then overshoots the aimed position
## by a few percent and settles back onto it. settle = 0 gives a plain smoothstep.
static func visual_blend(aim_blend: float, settle: float) -> float:
	var t: float = clampf(aim_blend, 0.0, 1.0)
	return smoothstep(0.0, 1.0, t) + settle * sin(t * PI) * t * t


## Metres the gun dips below its straight path at the middle of the move (0 at hip and when aimed).
static func arc_offset_m(aim_blend: float, arc_m: float) -> float:
	return arc_m * sin(clampf(aim_blend, 0.0, 1.0) * PI)


## Spring stiffness for a move that should reach 95 % of the way in ads_time seconds.
static func spring_omega(ads_time: float) -> float:
	return REACH_95 / maxf(ads_time, 0.05)


## Damping ratio: raising the gun overshoots the sights a little by settle (0 = none, 1 critically damped);
## lowering it never bounces.
static func spring_zeta(settle: float, raising: bool) -> float:
	if not raising:
		return 1.0
	return clampf(1.0 - settle, 0.45, 1.0)


## Advances the aim spring one frame toward target (0 hip, 1 aimed). Returns [value, velocity]. Velocity carries
## over when the target flips, so letting go half-way turns the gun round smoothly instead of kinking.
static func spring_step(value: float, velocity: float, target: float, omega: float, zeta: float, delta: float) -> Array:
	var x: float = value
	var v: float = velocity
	var left: float = delta
	while left > 0.0:
		var dt: float = minf(left, MAX_STEP_S)
		v += (omega * omega * (target - x) - 2.0 * zeta * omega * v) * dt
		x += v * dt
		left -= dt
	return [x, v]
