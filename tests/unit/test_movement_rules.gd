extends GdUnitTestSuite
## MovementRules: speeds per stance, sprint conditions, acceleration choice.

var _settings: PlayerMovementSettings = PlayerMovementSettings.new()


func test_walk_speed() -> void:
	assert_float(MovementRules.target_speed(_settings, false, false, false)).is_equal(_settings.walk_speed)


func test_sprint_speed() -> void:
	assert_float(MovementRules.target_speed(_settings, false, true, false)).is_equal(_settings.sprint_speed)


func test_crouch_overrides_sprint() -> void:
	assert_float(MovementRules.target_speed(_settings, true, true, false)).is_equal(_settings.crouch_speed)


func test_aiming_slows_down() -> void:
	assert_float(MovementRules.target_speed(_settings, false, false, true)) \
		.is_equal_approx(_settings.walk_speed * _settings.aim_speed_multiplier, 0.0001)


func test_sprint_needs_forward_input() -> void:
	assert_bool(MovementRules.can_sprint(Vector2(0.0, 1.0), true, false)).is_true()
	assert_bool(MovementRules.can_sprint(Vector2(1.0, 0.0), true, false)).is_false()
	assert_bool(MovementRules.can_sprint(Vector2(0.0, -1.0), true, false)).is_false()


func test_no_sprint_when_crouched_or_not_held() -> void:
	assert_bool(MovementRules.can_sprint(Vector2(0.0, 1.0), true, true)).is_false()
	assert_bool(MovementRules.can_sprint(Vector2(0.0, 1.0), false, false)).is_false()


func test_acceleration_choice() -> void:
	assert_float(MovementRules.acceleration(_settings, true, true)).is_equal(_settings.ground_acceleration)
	assert_float(MovementRules.acceleration(_settings, true, false)).is_equal(_settings.ground_deceleration)
	assert_float(MovementRules.acceleration(_settings, false, true)) \
		.is_equal_approx(_settings.ground_acceleration * _settings.air_control, 0.0001)
