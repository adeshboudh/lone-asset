extends GdUnitTestSuite
## NoiseRules, NoiseProfiles and ExposureRules.

const PROFILES: NoiseProfiles = preload("res://data/noise/noise_profiles.tres")


func test_each_wall_halves_the_radius() -> void:
	assert_float(NoiseRules.effective_radius(12.0, 0)).is_equal(12.0)
	assert_float(NoiseRules.effective_radius(12.0, 1)).is_equal(6.0)
	assert_float(NoiseRules.effective_radius(12.0, 2)).is_equal(3.0)


func test_wall_attenuation_stops_at_max_walls() -> void:
	assert_float(NoiseRules.effective_radius(8.0, 3)).is_equal(1.0)
	assert_float(NoiseRules.effective_radius(8.0, 10)).is_equal(1.0)


func test_is_heard_includes_the_exact_radius() -> void:
	assert_bool(NoiseRules.is_heard(4.0, 4.0)).is_true()
	assert_bool(NoiseRules.is_heard(4.01, 4.0)).is_false()


func test_footstep_type_by_stance() -> void:
	assert_str(NoiseRules.footstep_type(true, false)).is_equal(NoiseEvent.FOOTSTEP_CROUCH)
	assert_str(NoiseRules.footstep_type(false, true)).is_equal(NoiseEvent.FOOTSTEP_SPRINT)
	assert_str(NoiseRules.footstep_type(false, false)).is_equal(NoiseEvent.FOOTSTEP_WALK)
	assert_str(NoiseRules.footstep_type(true, true)).is_equal(NoiseEvent.FOOTSTEP_CROUCH)


func test_default_radii_match_the_design() -> void:
	assert_float(PROFILES.footstep_radius(NoiseEvent.FOOTSTEP_WALK)).is_equal(4.0)
	assert_float(PROFILES.footstep_radius(NoiseEvent.FOOTSTEP_SPRINT)).is_equal(12.0)
	assert_float(PROFILES.footstep_radius(NoiseEvent.FOOTSTEP_CROUCH)).is_equal(1.5)
	assert_float(PROFILES.landing_m).is_equal(8.0)
	assert_float(PROFILES.door_m).is_equal(10.0)
	assert_float(PROFILES.impact_m).is_equal(12.0)


func test_rifle_shot_radius() -> void:
	var rifle: WeaponDefinition = load("res://data/weapons/rifle_suppressed.tres")
	assert_bool(rifle.suppressed).is_true()
	assert_float(rifle.noise_radius_m).is_equal(18.0)


func test_surface_multipliers() -> void:
	assert_float(PROFILES.surface_multiplier(&"metal")).is_equal(1.5)
	assert_float(PROFILES.surface_multiplier(&"grass")).is_equal(0.7)
	assert_float(PROFILES.surface_multiplier(&"unlisted")).is_equal(1.0)


func test_exposure_pick_highest_priority() -> void:
	assert_int(ExposureRules.pick([1, 5, 3] as Array[int])).is_equal(1)


func test_exposure_pick_tie_goes_to_latest() -> void:
	assert_int(ExposureRules.pick([2, 2] as Array[int])).is_equal(1)


func test_exposure_pick_empty() -> void:
	assert_int(ExposureRules.pick([] as Array[int])).is_equal(-1)
