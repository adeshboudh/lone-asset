extends GdUnitTestSuite
## SettingsRules (pure logic).


func test_fov_is_kept_between_70_and_100() -> void:
	assert_float(SettingsRules.clamp_fov(50.0)).is_equal(70.0)
	assert_float(SettingsRules.clamp_fov(120.0)).is_equal(100.0)
	assert_float(SettingsRules.clamp_fov(85.0)).is_equal(85.0)


func test_sensitivity_is_clamped() -> void:
	assert_float(SettingsRules.clamp_sensitivity(0.0)).is_equal(SettingsRules.SENSITIVITY_MIN)
	assert_float(SettingsRules.clamp_sensitivity(9.0)).is_equal(SettingsRules.SENSITIVITY_MAX)


func test_zero_volume_is_silent_and_full_volume_is_zero_db() -> void:
	assert_float(SettingsRules.volume_db(0.0)).is_equal(-80.0)
	assert_float(SettingsRules.volume_db(1.0)).is_equal_approx(0.0, 0.001)
	assert_float(SettingsRules.volume_db(0.5)).is_equal_approx(-6.02, 0.05)


func test_invert_flips_only_the_vertical_look() -> void:
	assert_float(SettingsRules.look_y(3.0, false)).is_equal(3.0)
	assert_float(SettingsRules.look_y(3.0, true)).is_equal(-3.0)
