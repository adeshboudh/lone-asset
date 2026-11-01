extends GdUnitTestSuite
## GameStateMachine: allowed and rejected transitions, signal emission.

const State := GameStateMachine.State


func test_starts_in_boot() -> void:
	var machine: GameStateMachine = GameStateMachine.new()
	assert_int(machine.state).is_equal(State.BOOT)


func test_full_session_flow() -> void:
	var machine: GameStateMachine = GameStateMachine.new()
	var path: Array[State] = [
		State.TITLE, State.LOADING, State.PLAYING, State.PAUSED,
		State.PLAYING, State.MISSION_END, State.LOADING, State.PLAYING, State.PAUSED, State.TITLE,
	]
	for next: State in path:
		assert_bool(machine.transition(next)).override_failure_message(
			"Transition to %s rejected" % GameStateMachine.state_name(next)).is_true()
	assert_int(machine.state).is_equal(State.TITLE)


func test_rejects_invalid_transition_without_changing_state() -> void:
	var machine: GameStateMachine = GameStateMachine.new()
	assert_bool(machine.transition(State.PLAYING)).is_false()
	assert_int(machine.state).is_equal(State.BOOT)


func test_cannot_pause_from_title() -> void:
	var machine: GameStateMachine = GameStateMachine.new()
	machine.transition(State.TITLE)
	assert_bool(machine.can_transition(State.PAUSED)).is_false()


func test_cannot_transition_to_same_state() -> void:
	var machine: GameStateMachine = GameStateMachine.new()
	machine.transition(State.TITLE)
	assert_bool(machine.transition(State.TITLE)).is_false()


func test_emits_state_changed_with_old_and_new_state() -> void:
	var machine: GameStateMachine = GameStateMachine.new()
	var received: Array[int] = []
	machine.state_changed.connect(func(old_state: State, new_state: State) -> void:
		received.append(old_state)
		received.append(new_state))
	machine.transition(State.TITLE)
	machine.transition(State.PLAYING)  # rejected: must not emit
	assert_array(received).is_equal([State.BOOT, State.TITLE])


func test_state_name() -> void:
	assert_str(GameStateMachine.state_name(State.PAUSED)).is_equal("PAUSED")
