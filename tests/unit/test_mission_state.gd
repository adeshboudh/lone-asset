extends GdUnitTestSuite
## MissionState: objective order, gating, the optional stealth objective, failing.

const MISSION: MissionDefinition = preload("res://data/missions/m1_prototype.tres")
const Status := MissionState.Status

var _state: MissionState
var _checkpoints: Array[StringName]
var _completed: Array[bool]


func before_test() -> void:
	_state = MissionState.new()
	_checkpoints = []
	_completed = [false]
	_state.checkpoint_reached.connect(func(objective: ObjectiveDefinition) -> void: _checkpoints.append(objective.id))
	_state.completed.connect(func() -> void: _completed[0] = true)
	_state.start(MISSION)


func test_only_the_first_objective_and_the_stealth_bonus_start_active() -> void:
	assert_int(_state.status_of(&"obj_reach_compound")).is_equal(Status.ACTIVE)
	assert_int(_state.status_of(&"obj_download_data")).is_equal(Status.INACTIVE)
	assert_int(_state.status_of(&"obj_extract")).is_equal(Status.INACTIVE)
	assert_int(_state.status_of(&"obj_undetected")).is_equal(Status.ACTIVE)


func test_objectives_complete_in_order_and_the_mission_succeeds() -> void:
	_state.on_trigger(&"compound_inner")
	assert_int(_state.status_of(&"obj_download_data")).is_equal(Status.ACTIVE)
	_state.on_interaction(&"terminal_01")
	assert_int(_state.status_of(&"obj_extract")).is_equal(Status.ACTIVE)
	assert_bool(_completed[0]).is_false()
	_state.on_trigger(&"extraction_zone")
	assert_bool(_completed[0]).is_true()
	assert_bool(_state.was_successful).is_true()


func test_events_for_inactive_objectives_are_ignored() -> void:
	_state.on_trigger(&"extraction_zone")
	_state.on_interaction(&"terminal_01")
	assert_int(_state.status_of(&"obj_download_data")).is_equal(Status.INACTIVE)
	assert_int(_state.status_of(&"obj_extract")).is_equal(Status.INACTIVE)


func test_wrong_ids_do_not_complete_anything() -> void:
	_state.on_trigger(&"somewhere_else")
	assert_int(_state.status_of(&"obj_reach_compound")).is_equal(Status.ACTIVE)


func test_checkpoints_follow_objectives_that_ask_for_them() -> void:
	_state.on_trigger(&"compound_inner")
	_state.on_interaction(&"terminal_01")
	assert_array(_checkpoints).is_equal([&"obj_reach_compound", &"obj_download_data"])


func test_stealth_bonus_completes_when_no_guard_fought() -> void:
	_run_full_mission()
	assert_int(_state.status_of(&"obj_undetected")).is_equal(Status.COMPLETED)


func test_stealth_bonus_fails_once_a_guard_reaches_combat() -> void:
	_state.on_combat_reached()
	assert_int(_state.status_of(&"obj_undetected")).is_equal(Status.FAILED)
	_run_full_mission()
	assert_int(_state.status_of(&"obj_undetected")).is_equal(Status.FAILED)
	assert_bool(_state.was_successful).is_true()


func test_player_death_fails_the_mission() -> void:
	var reasons: Array[StringName] = []
	_state.failed.connect(func(reason: StringName) -> void: reasons.append(reason))
	_state.fail(&"player_died")
	assert_array(reasons).is_equal([&"player_died"])
	assert_bool(_state.is_finished).is_true()
	assert_bool(_state.was_successful).is_false()


func test_a_finished_mission_ignores_further_events() -> void:
	_state.fail(&"player_died")
	_state.on_trigger(&"compound_inner")
	assert_int(_state.status_of(&"obj_reach_compound")).is_equal(Status.ACTIVE)


func test_unlisted_fail_reasons_are_ignored() -> void:
	_state.fail(&"alarm_raised")
	assert_bool(_state.is_finished).is_false()


func _run_full_mission() -> void:
	_state.on_trigger(&"compound_inner")
	_state.on_interaction(&"terminal_01")
	_state.on_trigger(&"extraction_zone")
