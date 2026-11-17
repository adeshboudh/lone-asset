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


func _run(zeta: float, seconds: float, target: float = 1.0, value: float = 0.0, velocity: float = 0.0) -> Array:
	var state: Array = [value, velocity]
	var omega: float = AdsRules.spring_omega(0.2)
	for i: int in int(seconds * 60.0):
		state = AdsRules.spring_step(state[0], state[1], target, omega, zeta, 1.0 / 60.0)
	return state


func test_spring_reaches_95_percent_in_the_ads_time() -> void:
	assert_float(_run(1.0, 0.2)[0]).is_between(0.93, 0.97)
	assert_float(_run(1.0, 1.0)[0]).is_equal_approx(1.0, 0.001)


func test_critically_damped_spring_never_overshoots() -> void:
	var state: Array = [0.0, 0.0]
	var omega: float = AdsRules.spring_omega(0.2)
	for i: int in 120:
		state = AdsRules.spring_step(state[0], state[1], 1.0, omega, 1.0, 1.0 / 60.0)
		assert_float(state[0]).is_less_equal(1.0 + 0.0001)


func test_settle_makes_the_spring_overshoot_a_little_then_come_back() -> void:
	var zeta: float = AdsRules.spring_zeta(0.3, true)
	var peak: float = 0.0
	var state: Array = [0.0, 0.0]
	for i: int in 180:
		state = AdsRules.spring_step(state[0], state[1], 1.0, AdsRules.spring_omega(0.2), zeta, 1.0 / 60.0)
		peak = maxf(peak, state[0])
	assert_float(peak).is_between(1.01, 1.12)
	assert_float(state[0]).is_equal_approx(1.0, 0.001)


func test_lowering_the_gun_is_never_underdamped() -> void:
	assert_float(AdsRules.spring_zeta(0.5, false)).is_equal(1.0)


func test_releasing_half_way_turns_round_without_a_snap_or_a_bounce() -> void:
	var omega: float = AdsRules.spring_omega(0.2)
	var state: Array = [0.0, 0.0]
	for i: int in 6:
		state = AdsRules.spring_step(state[0], state[1], 1.0, omega, 1.0, 1.0 / 60.0)
	var value_before: float = state[0]
	var speed_before: float = state[1]
	assert_float(speed_before).is_greater(1.0)
	# The next frame the position has moved on by about one frame of the old speed: continuous, no snap to hip.
	state = AdsRules.spring_step(state[0], state[1], 0.0, omega, 1.0, 1.0 / 60.0)
	assert_float(absf(state[0] - value_before)).is_less(speed_before / 60.0 * 2.0)
	# Then it eases back to the hip without dipping below it.
	var lowest: float = state[0]
	for i: int in 180:
		state = AdsRules.spring_step(state[0], state[1], 0.0, omega, 1.0, 1.0 / 60.0)
		lowest = minf(lowest, state[0])
	assert_float(lowest).is_greater_equal(-0.001)
	assert_float(state[0]).is_equal_approx(0.0, 0.001)


func test_a_long_frame_is_split_and_stays_stable() -> void:
	var state: Array = AdsRules.spring_step(0.0, 0.0, 1.0, AdsRules.spring_omega(0.2), 1.0, 0.5)
	assert_float(state[0]).is_between(0.99, 1.01)

