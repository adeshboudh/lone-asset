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


func test_no_bob_when_standing_still_or_airborne() -> void:
	assert_vector(WeaponSwayRules.bob_position(_weapon, 1.0, 0.0, true, 0.0)).is_equal(Vector3.ZERO)
	assert_vector(WeaponSwayRules.bob_position(_weapon, 1.0, 5.0, false, 0.0)).is_equal(Vector3.ZERO)
	assert_vector(WeaponSwayRules.bob_rotation_deg(_weapon, 1.0, 5.0, false, 0.0)).is_equal(Vector3.ZERO)


func test_walking_forward_bobs_without_any_strafe() -> void:
	var offset: Vector3 = WeaponSwayRules.bob_position(_weapon, 0.0, _weapon.sway_ref_strafe_speed, true, 0.0)
	assert_float(offset.y).is_equal_approx(_weapon.bob_vertical_m, 0.0001)


func test_sprint_bobs_harder_and_tilts_muzzle_down() -> void:
	var sprint_speed: float = _weapon.sway_ref_strafe_speed * 1.8
	var walk: Vector3 = WeaponSwayRules.bob_rotation_deg(_weapon, PI * 0.5, _weapon.sway_ref_strafe_speed, true, 0.0)
	var sprint: Vector3 = WeaponSwayRules.bob_rotation_deg(_weapon, PI * 0.5, sprint_speed, true, 0.0)
	assert_float(sprint.z).is_greater(walk.z)
	assert_float(walk.x).is_equal(0.0)
	assert_float(sprint.x).is_less(0.0)


func test_aiming_reduces_bob() -> void:
	var hip: float = WeaponSwayRules.bob_position(_weapon, 0.0, _weapon.sway_ref_strafe_speed, true, 0.0).y
	var aimed: float = WeaponSwayRules.bob_position(_weapon, 0.0, _weapon.sway_ref_strafe_speed, true, 1.0).y
	assert_float(aimed).is_equal_approx(hip * _weapon.sway_ads_mult, 0.0001)


func test_bob_phase_follows_distance_and_wraps() -> void:
	# One stride walked is one step: half a cycle, so a footstep lands on every PI.
	assert_float(WeaponSwayRules.advance_bob_phase(0.0, 1.8, 1.8, true, 1.0)).is_equal_approx(PI, 0.0001)
	assert_float(WeaponSwayRules.advance_bob_phase(0.0, 2.4, 2.4, true, 1.0)).is_equal_approx(PI, 0.0001)
	assert_float(WeaponSwayRules.advance_bob_phase(1.5, 3.0, 1.8, false, 1.0)).is_equal(1.5)
	assert_float(WeaponSwayRules.advance_bob_phase(TAU - 0.01, 5.0, 1.8, true, 1.0)).is_less(TAU)
