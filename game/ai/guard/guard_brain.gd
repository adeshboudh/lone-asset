class_name GuardBrain
extends Node
## The guard's hierarchical state machine (design §7.2): runs the current GuardState and switches states.

signal state_changed(old_state: StringName, new_state: StringName)

var blackboard: GuardBlackboard = GuardBlackboard.new()
var current_name: StringName = &""
var current_state: GuardState:
	get:
		return _current

var _guard: Guard
var _states: Dictionary[StringName, GuardState] = {}
var _current: GuardState


func setup(guard: Guard) -> void:
	_guard = guard


func add_state(state_name: StringName, state: GuardState) -> void:
	state.guard = _guard
	state.blackboard = blackboard
	_states[state_name] = state


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func start(state_name: StringName) -> void:
	transition_to(state_name)


func tick(delta: float) -> void:
	if _current == null:
		return
	var next: StringName = _current.tick(delta)
	if next != &"" and next != current_name:
		transition_to(next)


## Leaves the current state and enters another. Unknown states are refused with a warning.
func transition_to(state_name: StringName) -> void:
	if not _states.has(state_name):
		Log.warn(&"ai", "Guard has no state '%s'" % state_name)
		return
	var old_name: StringName = current_name
	if _current != null:
		_current.exit()
	_current = _states[state_name]
	current_name = state_name
	_current.enter(old_name)
	state_changed.emit(old_name, state_name)
