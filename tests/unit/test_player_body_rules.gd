extends GdUnitTestSuite


func test_head_helmet_and_hands_are_hidden_from_the_camera() -> void:
	assert_bool(PlayerBodyRules.hidden_from_camera("pol head")).is_true()
	assert_bool(PlayerBodyRules.hidden_from_camera("pol helmet")).is_true()
	assert_bool(PlayerBodyRules.hidden_from_camera("pol hand")).is_true()


func test_clothing_stays_visible() -> void:
	for part: String in ["pol jaket", "pol pants", "boot war1", "pol bproof"]:
		assert_bool(PlayerBodyRules.hidden_from_camera(part)).is_false()


func test_name_match_ignores_case() -> void:
	assert_bool(PlayerBodyRules.hidden_from_camera("Helmet_01")).is_true()
