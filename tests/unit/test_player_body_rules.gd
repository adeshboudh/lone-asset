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


func test_hand_target_rises_when_aiming_and_drops_when_sprinting() -> void:
	var hold: Vector3 = Vector3(0.1, 1.3, -0.4)
	var ads: Vector3 = Vector3(-0.05, 0.1, 0.0)
	var sprint: Vector3 = Vector3(0.0, -0.2, 0.1)
	assert_float(PlayerBodyRules.hand_target(hold, ads, 1.0, sprint, 0.0, 0.0, 0.0).y).is_equal_approx(1.4, 0.0001)
	assert_float(PlayerBodyRules.hand_target(hold, ads, 0.0, sprint, 1.0, 0.0, 0.0).y).is_equal_approx(1.1, 0.0001)


func test_aiming_cancels_the_sprint_lowering() -> void:
	var hold: Vector3 = Vector3(0.1, 1.3, -0.4)
	var target: Vector3 = PlayerBodyRules.hand_target(hold, Vector3.ZERO, 1.0, Vector3(0.0, -0.2, 0.0), 1.0, 0.0, 0.0)
	assert_float(target.y).is_equal_approx(1.3, 0.0001)


func test_hand_target_follows_the_crouch_and_the_lean() -> void:
	var target: Vector3 = PlayerBodyRules.hand_target(Vector3(0.1, 1.3, -0.4), Vector3.ZERO, 0.0, Vector3.ZERO, 0.0, 0.65, 0.3)
	assert_vector(target).is_equal_approx(Vector3(0.4, 0.65, -0.4), Vector3(0.0001, 0.0001, 0.0001))
