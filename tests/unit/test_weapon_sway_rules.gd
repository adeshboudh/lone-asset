extends GdUnitTestSuite
## WeaponSwayRules: the viewmodel lags behind turning and strafing, less so when aimed.

var _weapon: WeaponDefinition = WeaponDefinition.new()


func test_standing_still_has_no_sway() -> void:
	assert_vector(WeaponSwayRules.target_position(_weapon, Vector2.ZERO, 0.0, 0.0)).is_equal(Vector3.ZERO)
	assert_vector(WeaponSwayRules.target_rotation_deg(_weapon, Vector2.ZERO, 0.0, 0.0)).is_equal(Vector3.ZERO)


func test_turning_right_swings_muzzle_left_and_rolls() -> void:
	var rate: Vector2 = Vector2(deg_to_rad(_weapon.sway_ref_turn_deg_per_s), 0.0)
	var rotation_deg: Vector3 = WeaponSwayRules.target_rotation_deg(_weapon, rate, 0.0, 0.0)
	assert_float(rotation_deg.y).is_equal_approx(_weapon.sway_yaw_deg, 0.001)
	assert_float(rotation_deg.z).is_equal_approx(_weapon.sway_roll_deg, 0.001)
	assert_float(WeaponSwayRules.target_position(_weapon, rate, 0.0, 0.0).x).is_less(0.0)


func test_looking_up_drops_the_muzzle() -> void:
	var rate: Vector2 = Vector2(0.0, deg_to_rad(_weapon.sway_ref_turn_deg_per_s))
	assert_float(WeaponSwayRules.target_rotation_deg(_weapon, rate, 0.0, 0.0).x).is_less(0.0)
	assert_float(WeaponSwayRules.target_position(_weapon, rate, 0.0, 0.0).y).is_less(0.0)


func test_strafing_right_shifts_left_and_rolls() -> void:
	var rotation_deg: Vector3 = WeaponSwayRules.target_rotation_deg(_weapon, Vector2.ZERO, _weapon.sway_ref_strafe_speed, 0.0)
	assert_float(rotation_deg.z).is_equal_approx(_weapon.sway_strafe_roll_deg, 0.001)
	assert_float(WeaponSwayRules.target_position(_weapon, Vector2.ZERO, _weapon.sway_ref_strafe_speed, 0.0).x).is_less(0.0)


func test_sway_is_clamped_to_the_reference_rate() -> void:
	var fast: Vector2 = Vector2(deg_to_rad(_weapon.sway_ref_turn_deg_per_s) * 10.0, 0.0)
	assert_float(WeaponSwayRules.target_rotation_deg(_weapon, fast, 0.0, 0.0).y).is_equal_approx(_weapon.sway_yaw_deg, 0.001)


func test_aiming_reduces_sway() -> void:
	var rate: Vector2 = Vector2(deg_to_rad(_weapon.sway_ref_turn_deg_per_s), 0.0)
	var hip: float = WeaponSwayRules.target_rotation_deg(_weapon, rate, 0.0, 0.0).y
	var aimed: float = WeaponSwayRules.target_rotation_deg(_weapon, rate, 0.0, 1.0).y
	assert_float(aimed).is_equal_approx(hip * _weapon.sway_ads_mult, 0.001)


func test_approach_moves_toward_target_and_never_overshoots() -> void:
	var next: Vector3 = WeaponSwayRules.approach(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 12.0, 1.0 / 60.0)
	assert_float(next.x).is_between(0.0, 1.0)
	assert_float(WeaponSwayRules.approach(Vector3(1.0, 0, 0), Vector3(1.0, 0, 0), 12.0, 0.016).x).is_equal_approx(1.0, 0.0001)
	assert_float(WeaponSwayRules.approach(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 12.0, 100.0).x).is_equal_approx(1.0, 0.0001)
