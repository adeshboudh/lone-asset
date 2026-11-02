class_name SettingsRules
extends RefCounted
## Pure rules for the player settings (design §15).

const FOV_MIN: float = 70.0
const FOV_MAX: float = 100.0
const SENSITIVITY_MIN: float = 0.25
const SENSITIVITY_MAX: float = 3.0
const RENDER_SCALE_MIN: float = 0.5
const RENDER_SCALE_MAX: float = 1.0

enum Quality { LOW, MEDIUM, HIGH }

## What each quality preset turns on (design §9). Render scale is a separate setting.
const PRESETS: Dictionary = {
	Quality.LOW: {"shadow_size": 1024, "soft_shadows": 0, "msaa": 0, "fxaa": true, "ssao": false, "glow": false},
	Quality.MEDIUM: {"shadow_size": 2048, "soft_shadows": 1, "msaa": 0, "fxaa": true, "ssao": false, "glow": true},
	Quality.HIGH: {"shadow_size": 4096, "soft_shadows": 2, "msaa": 2, "fxaa": false, "ssao": true, "glow": true},
}

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


static func clamp_render_scale(value: float) -> float:
	return clampf(value, RENDER_SCALE_MIN, RENDER_SCALE_MAX)


static func preset(quality: int) -> Dictionary:
	return PRESETS[clampi(quality, Quality.LOW, Quality.HIGH)]
