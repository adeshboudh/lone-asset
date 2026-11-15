extends GdUnitTestSuite


func test_lens_tan_is_radius_over_distance() -> void:
	assert_float(ScopeRules.lens_tan(0.01, 0.25)).is_equal_approx(0.04, 0.00001)


func test_lens_tan_survives_a_zero_distance() -> void:
	assert_float(ScopeRules.lens_tan(0.01, 0.0)).is_equal_approx(1.0, 0.00001)


func test_more_zoom_narrows_the_scope_camera() -> void:
	assert_float(ScopeRules.camera_fov_deg(0.04, 4.0)).is_less(ScopeRules.camera_fov_deg(0.04, 2.0))


func test_camera_fov_has_a_floor_and_a_ceiling() -> void:
	assert_float(ScopeRules.camera_fov_deg(0.0001, 8.0)).is_equal(0.5)
	assert_float(ScopeRules.camera_fov_deg(5.0, 1.0)).is_equal(60.0)


func test_zoom_below_one_acts_as_one() -> void:
	assert_float(ScopeRules.camera_fov_deg(0.04, 0.2)).is_equal_approx(ScopeRules.camera_fov_deg(0.04, 1.0), 0.0001)


func test_the_picture_fades_in_only_near_full_aim() -> void:
	assert_float(ScopeRules.picture_blend(0.5)).is_equal(0.0)
	assert_float(ScopeRules.picture_blend(1.0)).is_equal(1.0)
	assert_float(ScopeRules.picture_blend(0.8)).is_between(0.0, 1.0)


func test_renders_only_when_zoomed_and_aimed() -> void:
	assert_bool(ScopeRules.should_render(1.0, 3.0)).is_true()
	assert_bool(ScopeRules.should_render(0.3, 3.0)).is_false()
	assert_bool(ScopeRules.should_render(1.0, 1.0)).is_false()
