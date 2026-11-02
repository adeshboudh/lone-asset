extends GdUnitTestSuite
## SaveRules and MissionState save / load (pure logic).

const MISSION: MissionDefinition = preload("res://data/missions/m1_prototype.tres")


func _valid() -> Dictionary:
	return {"schema_version": 1, "mission_id": "m1_prototype", "objectives": {}, "player": {}, "guards": []}


func test_a_complete_current_save_is_accepted() -> void:
	assert_str(SaveRules.problem_with(_valid())).is_empty()


func test_text_that_is_not_a_save_is_rejected() -> void:
	assert_str(SaveRules.problem_with({})).is_not_empty()
	assert_dict(SaveRules.from_text("not json")).is_empty()
	assert_dict(SaveRules.from_text("[1, 2]")).is_empty()


func test_saves_from_a_newer_version_are_rejected() -> void:
	var data: Dictionary = _valid()
	data["schema_version"] = SaveRules.SCHEMA_VERSION + 1
	assert_str(SaveRules.problem_with(data)).contains("newer")


func test_a_save_missing_a_section_is_rejected() -> void:
	var data: Dictionary = _valid()
	data.erase("guards")
	assert_str(SaveRules.problem_with(data)).contains("guards")


func test_text_round_trip_keeps_the_data() -> void:
	var data: Dictionary = _valid()
	data["player"] = {"health": 72.5}
	var back: Dictionary = SaveRules.from_text(SaveRules.to_text(data))
	assert_float(back["player"]["health"]).is_equal(72.5)


func test_vectors_round_trip_and_bad_arrays_become_zero() -> void:
	var v: Vector3 = Vector3(12.0, 0.5, -4.25)
	assert_vector(SaveRules.array_to_vector(SaveRules.vector_to_array(v))).is_equal_approx(v, Vector3(0.001, 0.001, 0.001))
	assert_vector(SaveRules.array_to_vector([1.0])).is_equal(Vector3.ZERO)
	assert_vector(SaveRules.array_to_vector("x")).is_equal(Vector3.ZERO)


func test_mission_progress_survives_save_and_load() -> void:
	var state: MissionState = MissionState.new()
	state.start(MISSION)
	state.on_trigger(&"compound_inner")
	state.on_combat_reached()
	var saved: Dictionary = state.save_state()
	var restored: MissionState = MissionState.new()
	restored.start(MISSION)
	restored.load_state(saved["objectives"], saved["combat_reached"])
	assert_int(restored.status_of(&"obj_reach_compound")).is_equal(MissionState.Status.COMPLETED)
	assert_int(restored.status_of(&"obj_download_data")).is_equal(MissionState.Status.ACTIVE)
	assert_int(restored.status_of(&"obj_undetected")).is_equal(MissionState.Status.FAILED)
	assert_bool(restored.combat_reached).is_true()
