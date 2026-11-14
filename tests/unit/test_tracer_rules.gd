extends GdUnitTestSuite


func test_every_shot_when_interval_is_one_or_less() -> void:
	assert_bool(TracerRules.shows_tracer(0, 1)).is_true()
	assert_bool(TracerRules.shows_tracer(7, 1)).is_true()
	assert_bool(TracerRules.shows_tracer(3, 0)).is_true()


func test_every_nth_shot_starting_with_the_first() -> void:
	var shown: Array[int] = []
	for i: int in 11:
		if TracerRules.shows_tracer(i, 5):
			shown.append(i)
	assert_array(shown).is_equal([0, 5, 10])


func test_nothing_drawn_before_start_distance() -> void:
	assert_float(TracerRules.visible_length(2.0, 3.0, 2.5)).is_equal(0.0)
	assert_float(TracerRules.visible_length(3.0, 3.0, 2.5)).is_equal(0.0)


func test_streak_grows_then_caps_at_full_length() -> void:
	assert_float(TracerRules.visible_length(4.0, 3.0, 2.5)).is_equal_approx(1.0, 0.0001)
	assert_float(TracerRules.visible_length(50.0, 3.0, 2.5)).is_equal(2.5)
