class_name BinocularsRules
extends RefCounted
## Pure rules for the binoculars (design §13): zoom steps, field of view and tag timing.

const ZOOM_LEVELS: Array[float] = [4.0, 8.0]
## Seconds a guard must stay in the centre of the view to be tagged.
const TAG_HOLD_S: float = 0.5
## How long a tag lasts.
const TAG_DURATION_S: float = 60.0
## Half-angle of the tagging cone around the view centre.
const TAG_CONE_DEG: float = 2.0
const MAX_TAG_RANGE_M: float = 200.0
## Tag progress drains this many times faster than it fills when the guard leaves the centre.
const PROGRESS_DRAIN_FACTOR: float = 2.0


## Zoom level index after moving `step` levels (+1 zooms in, -1 out), kept within the available levels.
static func step_zoom(index: int, step: int) -> int:
	return clampi(index + step, 0, ZOOM_LEVELS.size() - 1)


## Vertical field of view (degrees) that magnifies the base view by `zoom`.
static func fov_for_zoom(base_fov_deg: float, zoom: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov_deg) * 0.5) / zoom))


## Tag progress (0–1) after another delta seconds.
static func advance_tag(progress: float, delta: float, centred: bool) -> float:
	if centred:
		return clampf(progress + delta / TAG_HOLD_S, 0.0, 1.0)
	return clampf(progress - delta * PROGRESS_DRAIN_FACTOR / TAG_HOLD_S, 0.0, 1.0)


static func in_tag_cone(angle_deg: float, distance_m: float) -> bool:
	return angle_deg <= TAG_CONE_DEG and distance_m <= MAX_TAG_RANGE_M
