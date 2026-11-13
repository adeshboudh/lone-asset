extends GdUnitTestSuite


func test_zero_spread_keeps_the_minimum_gap() -> void:
	assert_float(CrosshairRules.gap_px(0.0, 80.0, 360.0)).is_equal(CrosshairRules.MIN_GAP_PX)


func test_gap_grows_with_spread() -> void:
	assert_float(CrosshairRules.gap_px(3.0, 80.0, 360.0)).is_greater(CrosshairRules.gap_px(1.0, 80.0, 360.0))


func test_gap_is_wider_when_zoomed_in() -> void:
	assert_float(CrosshairRules.gap_px(2.0, 55.0, 360.0)).is_greater(CrosshairRules.gap_px(2.0, 80.0, 360.0))


func test_gap_matches_the_cone_edge() -> void:
	# a cone half-angle equal to half the FOV reaches the screen edge
	assert_float(CrosshairRules.gap_px(40.0, 80.0, 360.0)).is_equal_approx(360.0, 0.01)
