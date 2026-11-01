class_name GameStateMachine
extends RefCounted
## Top-level game states and the allowed transitions between them (design §2.2).
## Pure logic with no scene dependencies, so it is unit-tested directly.

signal state_changed(old_state: State, new_state: State)

enum State { BOOT, TITLE, LOADING, PLAYING, PAUSED, MISSION_END }

const TRANSITIONS: Dictionary = {
	State.BOOT: [State.TITLE],
	State.TITLE: [State.LOADING],
	State.LOADING: [State.PLAYING, State.TITLE],
	State.PLAYING: [State.PAUSED, State.MISSION_END, State.TITLE],
	State.PAUSED: [State.PLAYING, State.TITLE],
	State.MISSION_END: [State.LOADING, State.TITLE],
}

var state: State = State.BOOT


static func state_name(value: State) -> String:
	return str(State.keys()[value])


func can_transition(to: State) -> bool:
	var allowed: Array = TRANSITIONS[state]
	return to in allowed


## Changes state and emits state_changed. Returns false, changing nothing, if the transition is not allowed.
func transition(to: State) -> bool:
	if not can_transition(to):
		return false
	var old_state: State = state
	state = to
	state_changed.emit(old_state, to)
	return true
