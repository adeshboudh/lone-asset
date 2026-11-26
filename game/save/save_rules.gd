class_name SaveRules
extends RefCounted
## Pure rules for checkpoint files (design §16): the schema version, validation and migration.

## 2: weapons hold a magazine and a chambered round, the player has an inventory (pouches, loose ammo).
## 3: the inventory also has a backpack, the player has a condition (a save without them loads with an empty backpack
## and a default condition).
const SCHEMA_VERSION: int = 3


## "" if the data can be loaded, otherwise a reason to show the player.
static func problem_with(data: Dictionary) -> String:
	if not data.has("schema_version"):
		return "This is not a Lone Asset save."
	var version: int = int(data["schema_version"])
	if version > SCHEMA_VERSION:
		return "This save was made by a newer version of the game."
	if version < 1:
		return "This save is damaged."
	for key: String in ["mission_id", "objectives", "player", "guards"]:
		if not data.has(key):
			return "This save is incomplete (missing %s)." % key
	return ""


## Brings older saves up to the current schema. Version 1 saves keep their `mag` and `reserve` numbers; Player.load_state
## turns them into magazines and loose ammo (a save with no `inventory` key is a version 1 save).
static func migrate(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	migrated["schema_version"] = SCHEMA_VERSION
	return migrated


static func to_text(data: Dictionary) -> String:
	return JSON.stringify(data, "\t")


## The parsed save, or an empty dictionary if the text is not a JSON object.
static func from_text(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func vector_to_array(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


static func array_to_vector(a: Variant) -> Vector3:
	var values: Array = a if a is Array else []
	if values.size() != 3:
		return Vector3.ZERO
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
