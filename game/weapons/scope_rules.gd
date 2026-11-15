class_name ScopeRules
extends RefCounted
## Picture-in-picture scope maths: the lens shows a second camera zoomed in on where the gun points.


## Half-angle tangent of the lens as the eye sees it: lens radius over the eye-to-lens distance.
static func lens_tan(lens_radius_m: float, eye_distance_m: float) -> float:
	return lens_radius_m / maxf(eye_distance_m, 0.01)


## Vertical field of view (degrees) of the scope camera. It covers what the lens subtends divided by the zoom,
## with a small margin so the lens edge never shows the border of the picture.
static func camera_fov_deg(lens_tan_value: float, zoom: float) -> float:
	var half_tan: float = lens_tan_value * 1.05 / maxf(zoom, 1.0)
	return clampf(rad_to_deg(2.0 * atan(half_tan)), 0.5, 60.0)


## How much of the scope picture shows: 0 until the gun is mostly raised, 1 once aimed.
static func picture_blend(aim_blend: float) -> float:
	return smoothstep(0.6, 1.0, aim_blend)


## The scope camera only renders while the picture can be seen.
static func should_render(aim_blend: float, zoom: float) -> bool:
	return zoom > 1.0 and aim_blend > 0.55
