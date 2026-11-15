class_name PlayerBodyRules
extends RefCounted
## Rules for the player's visible body (design §4). Pure functions, unit-tested.

## Body parts the first-person camera must not see: the head and helmet would fill the view, and the
## hands are replaced by the weapon viewmodel's own. Matched against mesh names, lower case.
const HIDDEN_FROM_CAMERA: PackedStringArray = ["head", "helmet", "hand"]


static func hidden_from_camera(mesh_name: String) -> bool:
	var lower: String = mesh_name.to_lower()
	for part: String in HIDDEN_FROM_CAMERA:
		if lower.contains(part):
			return true
	return false


## Vertical scale of the body for the current eye height. Placeholder until crouch has its own
## animation: the model is squashed part-way so the feet stay on the floor and the head follows the eye.
static func height_scale(eye_height: float, stand_eye_height: float, strength: float) -> float:
	if stand_eye_height <= 0.0:
		return 1.0
	return lerpf(1.0, clampf(eye_height / stand_eye_height, 0.0, 1.0), strength)
