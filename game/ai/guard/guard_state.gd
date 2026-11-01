class_name GuardState
extends RefCounted
## One state of the guard's hierarchical state machine (design §7.2). Narrow on purpose, so the machine
## can be swapped for behaviour trees later without touching perception or movement.

const PATROL: StringName = &"patrol"
const INVESTIGATE: StringName = &"investigate"
const SEARCH: StringName = &"search"
const COMBAT: StringName = &"combat"
const RETURN_TO_PATROL: StringName = &"return_to_patrol"
const DEAD: StringName = &"dead"

var guard: Guard
var blackboard: GuardBlackboard


## `previous` is the state that was left, or &"" at start-up.
func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


## Returns the name of the state to switch to, or &"" to stay.
func tick(_delta: float) -> StringName:
	return &""


## Extra detail for the F3 debug label.
func debug_text() -> String:
	return ""
