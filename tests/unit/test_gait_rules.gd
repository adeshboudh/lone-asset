extends GdUnitTestSuite


func test_phase_advances_by_pi_per_stride() -> void:
	assert_float(GaitRules.advance_phase(0.0, 2.0, 2.0, 1.0)).is_equal_approx(PI, 0.0001)


func test_phase_wraps() -> void:
	assert_float(GaitRules.advance_phase(TAU - 0.1, 2.0, 2.0, 0.1)).is_less(TAU)


func test_standing_still_does_not_advance_the_phase() -> void:
	assert_float(GaitRules.advance_phase(1.0, 0.0, 1.0, 0.5)).is_equal_approx(1.0, 0.0001)


func test_foot_swings_forward_while_lifted() -> void:
	var early: Vector2 = GaitRules.foot_offset(0.2, 0.3, 0.1)
	var late: Vector2 = GaitRules.foot_offset(PI - 0.2, 0.3, 0.1)
	assert_float(late.x).is_greater(early.x)
	assert_float(early.y).is_greater(0.0)


func test_foot_is_on_the_floor_and_moving_back_during_stance() -> void:
	var a: Vector2 = GaitRules.foot_offset(PI + 0.5, 0.3, 0.1)
	var b: Vector2 = GaitRules.foot_offset(PI + 1.0, 0.3, 0.1)
	assert_float(a.y).is_equal(0.0)
	assert_float(b.x).is_less(a.x)


func test_stance_foot_moves_back_at_ground_speed_in_mid_stance() -> void:
	var speed: float = 3.0
	var stride: float = 1.0
	var amplitude: float = GaitRules.foot_amplitude_m(stride, 10.0)
	var phase: float = PI * 1.5
	var dt: float = 0.001
	var before: float = GaitRules.foot_offset(phase, amplitude, 0.1).x
	var after: float = GaitRules.foot_offset(GaitRules.advance_phase(phase, speed, stride, dt), amplitude, 0.1).x
	assert_float((before - after) / dt).is_equal_approx(speed, 0.05)


func test_pelvis_is_lowest_with_both_feet_down_and_never_rises_above_zero() -> void:
	assert_float(GaitRules.pelvis_offset_m(0.0, 0.06)).is_equal_approx(-0.06, 0.0001)
	assert_float(GaitRules.pelvis_offset_m(PI * 0.5, 0.06)).is_equal_approx(0.0, 0.0001)


func test_crouch_amount_follows_the_eye_height() -> void:
	assert_float(GaitRules.crouch_amount(1.65, 1.65, 1.0)).is_equal_approx(0.0, 0.0001)
	assert_float(GaitRules.crouch_amount(1.0, 1.65, 1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(GaitRules.crouch_amount(1.325, 1.65, 1.0)).is_equal_approx(0.5, 0.0001)


func test_landing_dip_scales_with_fall_speed() -> void:
	assert_float(GaitRules.landing_dip_m(1.0, 0.2)).is_equal(0.0)
	assert_float(GaitRules.landing_dip_m(8.0, 0.2)).is_equal_approx(0.2, 0.0001)
	assert_float(GaitRules.landing_dip_m(5.0, 0.2)).is_equal_approx(0.1, 0.0001)
