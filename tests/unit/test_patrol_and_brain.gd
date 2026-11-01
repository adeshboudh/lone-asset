extends GdUnitTestSuite
## PatrolSequence ordering and the GuardBrain state machine.


class RecordingState extends GuardState:
	var log: Array[String]
	var label: String
	var next: StringName = &""

	func enter(previous: StringName) -> void:
		log.append("enter %s (from %s)" % [label, previous])

	func exit() -> void:
		log.append("exit %s" % label)

	func tick(_delta: float) -> StringName:
		return next


func _sequence(count: int, mode: PatrolSequence.Mode, start: int = 0) -> Array[int]:
	var seq: PatrolSequence = PatrolSequence.new(count, mode, start)
	var order: Array[int] = [seq.index]
	for i: int in 7:
		order.append(seq.advance())
	return order


func test_loop_wraps_around() -> void:
	assert_array(_sequence(3, PatrolSequence.Mode.LOOP)).is_equal([0, 1, 2, 0, 1, 2, 0, 1])


func test_ping_pong_bounces_at_both_ends() -> void:
	assert_array(_sequence(3, PatrolSequence.Mode.PING_PONG)).is_equal([0, 1, 2, 1, 0, 1, 2, 1])


func test_ping_pong_with_two_points() -> void:
	assert_array(_sequence(2, PatrolSequence.Mode.PING_PONG)).is_equal([0, 1, 0, 1, 0, 1, 0, 1])


func test_single_and_empty_routes_stay_put() -> void:
	assert_array(_sequence(1, PatrolSequence.Mode.LOOP)).is_equal([0, 0, 0, 0, 0, 0, 0, 0])
	assert_array(_sequence(0, PatrolSequence.Mode.PING_PONG)).is_equal([0, 0, 0, 0, 0, 0, 0, 0])


func test_start_index_is_clamped_and_respected() -> void:
	assert_array(_sequence(4, PatrolSequence.Mode.LOOP, 2)).is_equal([2, 3, 0, 1, 2, 3, 0, 1])
	assert_int(PatrolSequence.new(3, PatrolSequence.Mode.LOOP, 99).index).is_equal(2)


func test_brain_enters_exits_and_reports_transitions() -> void:
	var brain: GuardBrain = auto_free(GuardBrain.new())
	var log: Array[String] = []
	var a: RecordingState = RecordingState.new()
	var b: RecordingState = RecordingState.new()
	a.label = "A"
	b.label = "B"
	a.log = log
	b.log = log
	brain.add_state(&"a", a)
	brain.add_state(&"b", b)
	var changes: Array[String] = []
	brain.state_changed.connect(func(old_state: StringName, new_state: StringName) -> void: changes.append("%s>%s" % [old_state, new_state]))
	brain.start(&"a")
	a.next = &"b"
	brain.tick(0.016)
	assert_array(log).is_equal(["enter A (from )", "exit A", "enter B (from a)"])
	assert_array(changes).is_equal([">a", "a>b"])
	assert_str(brain.current_name).is_equal("b")


func test_brain_stays_when_state_returns_nothing_or_itself() -> void:
	var brain: GuardBrain = auto_free(GuardBrain.new())
	var a: RecordingState = RecordingState.new()
	a.log = []
	brain.add_state(&"a", a)
	brain.start(&"a")
	brain.tick(0.016)
	a.next = &"a"
	brain.tick(0.016)
	assert_array(a.log).has_size(1)


func test_brain_refuses_unknown_state() -> void:
	var brain: GuardBrain = auto_free(GuardBrain.new())
	var a: RecordingState = RecordingState.new()
	a.log = []
	brain.add_state(&"a", a)
	brain.start(&"a")
	brain.transition_to(&"missing")
	assert_str(brain.current_name).is_equal("a")
