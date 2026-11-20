extends GdUnitTestSuite

var _profile: GuardAnimationProfile = GuardAnimationProfile.new()


func test_standing_still_idles_relaxed_or_aiming() -> void:
	assert_str(GuardAnimationRules.clip_for(GuardState.PATROL, 0.0, _profile)).is_equal(String(_profile.relaxed_idle))
	assert_str(GuardAnimationRules.clip_for(GuardState.COMBAT, 0.0, _profile)).is_equal(String(_profile.aim_idle))


func test_patrol_walks_and_combat_run_uses_aim_jog() -> void:
	assert_str(GuardAnimationRules.clip_for(GuardState.PATROL, 1.5, _profile)).is_equal(String(_profile.relaxed_walk))
	assert_str(GuardAnimationRules.clip_for(GuardState.COMBAT, 4.5, _profile)).is_equal(String(_profile.aim_jog))
	assert_str(GuardAnimationRules.clip_for(GuardState.INVESTIGATE, 2.0, _profile)).is_equal(String(_profile.aim_walk))


func test_weapon_ready_states() -> void:
	assert_bool(GuardAnimationRules.weapon_ready(GuardState.PATROL)).is_false()
	assert_bool(GuardAnimationRules.weapon_ready(GuardState.RETURN_TO_PATROL)).is_false()
	assert_bool(GuardAnimationRules.weapon_ready(GuardState.SEARCH)).is_true()


func test_speed_scale_matches_ground_speed_and_is_clamped() -> void:
	assert_float(GuardAnimationRules.speed_scale(0.0, _profile)).is_equal(1.0)
	assert_float(GuardAnimationRules.speed_scale(_profile.walk_clip_speed, _profile)).is_equal_approx(1.0, 0.0001)
	assert_float(GuardAnimationRules.speed_scale(0.3, _profile)).is_equal(_profile.min_speed_scale)
	assert_float(GuardAnimationRules.speed_scale(20.0, _profile)).is_equal(_profile.max_speed_scale)
