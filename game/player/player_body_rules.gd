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
