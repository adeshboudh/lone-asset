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


## Where a hand goes (body space, metres from the feet): the weapon's hold point, raised toward the
## sights when aiming, lowered and pulled in when sprinting, dropped with the eyes when crouching and
## shifted sideways when leaning.
static func hand_target(hold: Vector3, ads_offset: Vector3, aim_blend: float, sprint_offset: Vector3, sprint_blend: float,
		eye_drop_m: float, lean_shift_m: float) -> Vector3:
	var aimed: Vector3 = hold + ads_offset * aim_blend
	aimed += sprint_offset * sprint_blend * (1.0 - aim_blend)
	return aimed + Vector3(lean_shift_m, -eye_drop_m, 0.0)


## Both hands at the eyes for binoculars (x is the hand's side: -1 left, 1 right).
static func binocular_hand(side: float, eye_height: float) -> Vector3:
	return Vector3(0.06 * side, eye_height - 0.12, -0.3)
