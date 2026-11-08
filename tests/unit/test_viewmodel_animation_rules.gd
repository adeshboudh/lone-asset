extends GdUnitTestSuite


func test_natural_speed_without_a_target_duration() -> void:
	assert_float(ViewmodelAnimationRules.speed_for(2.0, 0.0)).is_equal(1.0)


func test_stretches_a_long_animation_to_a_short_reload() -> void:
	assert_float(ViewmodelAnimationRules.speed_for(3.0, 1.5)).is_equal(2.0)


func test_slows_a_short_animation_to_a_long_reload() -> void:
	assert_float(ViewmodelAnimationRules.speed_for(1.0, 2.0)).is_equal(0.5)


func test_speed_is_clamped() -> void:
	assert_float(ViewmodelAnimationRules.speed_for(10.0, 0.5)).is_equal(ViewmodelAnimationRules.MAX_SPEED)
	assert_float(ViewmodelAnimationRules.speed_for(0.1, 5.0)).is_equal(ViewmodelAnimationRules.MIN_SPEED)


func test_empty_animation_is_natural_speed() -> void:
	assert_float(ViewmodelAnimationRules.speed_for(0.0, 2.0)).is_equal(1.0)
