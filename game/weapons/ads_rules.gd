class_name AdsRules
extends RefCounted
## Look of the hip-to-aim move (design §5.2). aim_blend stays linear for gameplay (spread, FOV);
## the viewmodel uses these curves so the gun eases in, settles past the sights and returns.


## Viewmodel blend for a linear aim_blend (0-1). Eases in and out, then overshoots the aimed position
## by a few percent and settles back onto it. settle = 0 gives a plain smoothstep.
static func visual_blend(aim_blend: float, settle: float) -> float:
	var t: float = clampf(aim_blend, 0.0, 1.0)
	return smoothstep(0.0, 1.0, t) + settle * sin(t * PI) * t * t


## Metres the gun dips below its straight path at the middle of the move (0 at hip and when aimed).
static func arc_offset_m(aim_blend: float, arc_m: float) -> float:
	return arc_m * sin(clampf(aim_blend, 0.0, 1.0) * PI)
