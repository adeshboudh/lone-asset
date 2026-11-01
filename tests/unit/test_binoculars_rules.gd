extends GdUnitTestSuite
## BinocularsRules (pure logic).


func test_zoom_steps_stay_within_the_levels() -> void:
	assert_int(BinocularsRules.step_zoom(0, 1)).is_equal(1)
	assert_int(BinocularsRules.step_zoom(1, 1)).is_equal(1)
	assert_int(BinocularsRules.step_zoom(1, -1)).is_equal(0)
	assert_int(BinocularsRules.step_zoom(0, -3)).is_equal(0)


func test_fov_shrinks_so_the_image_is_magnified() -> void:
	var fov: float = BinocularsRules.fov_for_zoom(75.0, 4.0)
	assert_float(tan(deg_to_rad(75.0) * 0.5) / tan(deg_to_rad(fov) * 0.5)).is_equal_approx(4.0, 0.001)
	assert_float(BinocularsRules.fov_for_zoom(75.0, 8.0)).is_less(fov)


func test_tag_fills_in_half_a_second_when_centred() -> void:
	var progress: float = 0.0
	for i: int in 30:
		progress = BinocularsRules.advance_tag(progress, 1.0 / 60.0, true)
	assert_float(progress).is_equal_approx(1.0, 0.001)


func test_tag_drains_faster_than_it_fills() -> void:
	assert_float(BinocularsRules.advance_tag(0.5, 0.1, false)).is_equal_approx(0.5 - 0.1 * 2.0 / 0.5, 0.001)
	assert_float(BinocularsRules.advance_tag(0.1, 1.0, false)).is_equal(0.0)


func test_cone_and_range_limit_tagging() -> void:
	assert_bool(BinocularsRules.in_tag_cone(1.0, 50.0)).is_true()
	assert_bool(BinocularsRules.in_tag_cone(3.0, 50.0)).is_false()
	assert_bool(BinocularsRules.in_tag_cone(1.0, 250.0)).is_false()
