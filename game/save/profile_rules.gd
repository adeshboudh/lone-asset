class_name ProfileRules
extends RefCounted
## Pure rules for the profile that carries the operative between missions: health, condition, weapons with their
## magazines (every round), and the rig, backpack and loose ammo. Position, stance and the weapon slot belong to a
## checkpoint, not the profile.

const VERSION: int = 1
const KEPT_KEYS: Array[String] = ["health", "condition", "inventory", "loadout"]


## The profile for a player's `save_state()`.
static func build(player_state: Dictionary) -> Dictionary:
	var profile: Dictionary = {"profile_version": VERSION}
	for key: String in KEPT_KEYS:
		if player_state.has(key):
			profile[key] = player_state[key]
	return profile


## "" if the profile can be applied, otherwise the reason.
static func problem_with(data: Dictionary) -> String:
	if not data.has("profile_version"):
		return "This is not a Lone Asset profile."
	if int(data["profile_version"]) > VERSION:
		return "This profile was made by a newer version of the game."
	if not data.has("inventory") or not data["inventory"] is Dictionary:
		return "This profile has no inventory."
	return ""
