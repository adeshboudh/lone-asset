extends GdUnitTestSuite
## The procedural weapon switch curves.

const S: SwitchMotionSettings = preload("res://data/weapons/switch_motion.tres")


func test_holster_goes_from_rest_to_lowered_and_only_ever_rises() -> void:
	assert_float(SwitchMotionRules.holster_weight(0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(SwitchMotionRules.holster_weight(1.0)).is_equal_approx(1.0, 0.0001)
	var last: float = 0.0
	for i: int in 21:
		var w: float = SwitchMotionRules.holster_weight(i / 20.0)
		assert_float(w).is_greater_equal(last)
		last = w


func test_holster_starts_and_ends_gently() -> void:
	assert_float(SwitchMotionRules.holster_weight(0.05)).is_less(0.03)
	assert_float(SwitchMotionRules.holster_weight(0.95)).is_greater(0.97)


func test_draw_starts_lowered_and_ends_at_rest() -> void:
	assert_float(SwitchMotionRules.draw_weight(0.0, S.draw_time_s, S.draw_damping)).is_equal_approx(1.0, 0.0001)
	assert_float(SwitchMotionRules.draw_weight(S.draw_time_s, S.draw_time_s, S.draw_damping)).is_equal(0.0)
	assert_float(SwitchMotionRules.draw_weight(500.0, S.draw_time_s, S.draw_damping)).is_equal(0.0)


func test_draw_overshoots_a_little_then_settles() -> void:
	var lowest: float = 1.0
	for i: int in 200:
		lowest = minf(lowest, SwitchMotionRules.draw_weight(i * S.draw_time_s / 200.0, S.draw_time_s, S.draw_damping))
	assert_float(lowest).is_between(-0.2, -0.03)
	assert_float(absf(SwitchMotionRules.draw_weight(S.draw_time_s * 0.99, S.draw_time_s, S.draw_damping))).is_less(0.03)


func test_a_fully_damped_draw_does_not_overshoot() -> void:
	for i: int in 100:
		assert_float(SwitchMotionRules.draw_weight(i * S.draw_time_s / 100.0, S.draw_time_s, 0.99)).is_greater(-0.02)


func test_draw_rotation_trails_the_movement() -> void:
	var elapsed: float = 0.1
	assert_float(SwitchMotionRules.rotation_weight(0.0, elapsed, S)).is_greater(SwitchMotionRules.position_weight(0.0, elapsed, S))


func test_nothing_is_lowered_when_idle() -> void:
	assert_float(SwitchMotionRules.position_weight(0.0, 1000.0, S)).is_equal(0.0)
	assert_float(SwitchMotionRules.rotation_weight(0.0, 1000.0, S)).is_equal(0.0)
