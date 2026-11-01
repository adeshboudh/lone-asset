class_name SettingsRules
extends RefCounted
## Pure rules for the player settings (design §15).

const FOV_MIN: float = 70.0
const FOV_MAX: float = 100.0
const SENSITIVITY_MIN: float = 0.25
const SENSITIVITY_MAX: float = 3.0
## Volume sliders run 0–1; below this a bus is muted.
const SILENT_BELOW: float = 0.001


static func clamp_fov(value: float) -> float:
	return clampf(value, FOV_MIN, FOV_MAX)


static func clamp_sensitivity(value: float) -> float:
	return clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)


static func volume_db(linear: float) -> float:
	if linear < SILENT_BELOW:
		return -80.0
	return linear_to_db(clampf(linear, 0.0, 1.0))


## Vertical look delta after the invert option.
static func look_y(delta_y: float, invert: bool) -> float:
	return -delta_y if invert else delta_y
