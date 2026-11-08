class_name CrosshairRules
extends RefCounted
## Pure maths for the HUD crosshair.

## Smallest gap between the crosshair centre and its ticks, so it never closes to a point.
const MIN_GAP_PX: float = 3.0


## Pixels from the screen centre to each tick: where the spread cone (half-angle in degrees) meets
## the screen, for a camera with this vertical FOV and a screen this many pixels tall from the centre.
static func gap_px(spread_deg: float, fov_deg: float, half_height_px: float) -> float:
	var half_fov: float = tan(deg_to_rad(maxf(fov_deg, 1.0) * 0.5))
	return maxf(tan(deg_to_rad(maxf(spread_deg, 0.0))) / half_fov * half_height_px, MIN_GAP_PX)
