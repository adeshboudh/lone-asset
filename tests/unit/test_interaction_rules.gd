extends GdUnitTestSuite
## InteractionRules (pure logic).


func test_hold_progress_grows_with_time() -> void:
	assert_float(InteractionRules.advance_hold(0.0, 1.0, 4.0)).is_equal_approx(0.25, 0.0001)
	assert_float(InteractionRules.advance_hold(0.25, 2.0, 4.0)).is_equal_approx(0.75, 0.0001)


func test_hold_progress_stops_at_one() -> void:
	assert_float(InteractionRules.advance_hold(0.9, 5.0, 4.0)).is_equal(1.0)


func test_zero_duration_completes_at_once() -> void:
	assert_float(InteractionRules.advance_hold(0.0, 0.0, 0.0)).is_equal(1.0)
