class_name OperativeCondition
extends RefCounted
## What the inventory screen shows about the operative besides vital HP: active bleeding, injuries to the upper body
## and arms and to the legs (0 none, 1 light, 2 severe) and mental stress (0 to 100). Display only for now: nothing
## in the game reads these values yet. Saved with the checkpoint and the mission profile.

const MAX_INJURY: int = 2
const MAX_STRESS: float = 100.0

var bleeding: bool = false
var upper_injury: int = 0:
	set(value):
		upper_injury = clampi(value, 0, MAX_INJURY)
var lower_injury: int = 0:
	set(value):
		lower_injury = clampi(value, 0, MAX_INJURY)
var stress: float = 0.0:
	set(value):
		stress = clampf(value, 0.0, MAX_STRESS)


func to_dict() -> Dictionary:
	return {"bleeding": bleeding, "upper_injury": upper_injury, "lower_injury": lower_injury, "stress": stress}


static func from_dict(data: Variant) -> OperativeCondition:
	var condition: OperativeCondition = OperativeCondition.new()
	if data is Dictionary:
		var values: Dictionary = data
		condition.bleeding = bool(values.get("bleeding", false))
		condition.upper_injury = int(values.get("upper_injury", 0))
		condition.lower_injury = int(values.get("lower_injury", 0))
		condition.stress = float(values.get("stress", 0.0))
	return condition
