extends GdUnitTestSuite


func test_grazing_angle_is_zero_when_skimming_and_ninety_head_on() -> void:
	assert_float(ImpactRules.grazing_angle_deg(Vector3.FORWARD, Vector3.UP)).is_equal_approx(0.0, 0.001)
	assert_float(ImpactRules.grazing_angle_deg(Vector3.DOWN, Vector3.UP)).is_equal_approx(90.0, 0.001)
	assert_float(ImpactRules.grazing_angle_deg(Vector3(0.0, -1.0, -1.0), Vector3.UP)).is_equal_approx(45.0, 0.001)


func test_ricochet_needs_a_shallow_angle() -> void:
	assert_bool(ImpactRules.ricochets(15.0, 10.0, 0, 1)).is_true()
	assert_bool(ImpactRules.ricochets(15.0, 15.0, 0, 1)).is_true()
	assert_bool(ImpactRules.ricochets(15.0, 20.0, 0, 1)).is_false()


func test_surface_with_no_ricochet_angle_never_ricochets() -> void:
	assert_bool(ImpactRules.ricochets(0.0, 0.0, 0, 1)).is_false()


func test_ricochet_count_is_limited() -> void:
	assert_bool(ImpactRules.ricochets(15.0, 5.0, 1, 1)).is_false()


func test_reflect_flips_the_normal_component() -> void:
	var out: Vector3 = ImpactRules.reflect(Vector3(0.0, -1.0, -1.0), Vector3.UP)
	assert_float(out.y).is_greater(0.0)
	assert_float(out.z).is_less(0.0)
	assert_float(out.length()).is_equal_approx(1.0, 0.001)


func test_remaining_power_drops_with_thickness() -> void:
	assert_float(ImpactRules.remaining_power(100.0, 0.1, 250.0)).is_equal_approx(75.0, 0.001)


func test_remaining_power_never_goes_negative() -> void:
	assert_float(ImpactRules.remaining_power(100.0, 0.5, 250.0)).is_equal(0.0)
