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


func test_standing_keeps_full_height() -> void:
	assert_float(PlayerBodyRules.height_scale(1.65, 1.65, 0.6)).is_equal_approx(1.0, 0.0001)


func test_crouch_squashes_part_way() -> void:
	var scale: float = PlayerBodyRules.height_scale(1.0, 1.65, 0.6)
	assert_float(scale).is_less(1.0)
	assert_float(scale).is_greater(1.0 / 1.65)


func test_no_squash_when_strength_is_zero() -> void:
	assert_float(PlayerBodyRules.height_scale(1.0, 1.65, 0.0)).is_equal_approx(1.0, 0.0001)
