extends GdUnitTestSuite


func test_blend_hits_both_ends_exactly() -> void:
	assert_float(AdsRules.visual_blend(0.0, 0.3)).is_equal(0.0)
	assert_float(AdsRules.visual_blend(1.0, 0.3)).is_equal_approx(1.0, 0.0001)


func test_blend_overshoots_then_settles() -> void:
	var peak: float = 0.0
	for i: int in range(1, 100):
		peak = maxf(peak, AdsRules.visual_blend(float(i) / 100.0, 0.3))
	assert_float(peak).is_greater(1.0)
	assert_float(peak).is_less(1.1)


func test_no_settle_is_plain_smoothstep() -> void:
	assert_float(AdsRules.visual_blend(0.5, 0.0)).is_equal_approx(0.5, 0.0001)
	assert_float(AdsRules.visual_blend(0.25, 0.0)).is_equal_approx(smoothstep(0.0, 1.0, 0.25), 0.0001)


func test_arc_is_zero_at_the_ends_and_largest_in_the_middle() -> void:
	assert_float(AdsRules.arc_offset_m(0.0, 0.02)).is_equal_approx(0.0, 0.0001)
	assert_float(AdsRules.arc_offset_m(1.0, 0.02)).is_equal_approx(0.0, 0.0001)
	assert_float(AdsRules.arc_offset_m(0.5, 0.02)).is_equal_approx(0.02, 0.0001)
