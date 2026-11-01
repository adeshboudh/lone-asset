extends GdUnitTestSuite
## SuspicionRules, SuspicionModel and PerceptionRules (design §8 and §9). Pure logic, so no scenes.

const PROFILE: GuardProfile = preload("res://data/ai/guard_default.tres")
const Cone := PerceptionRules.Cone
const Motion := PerceptionRules.Motion
const Band := SuspicionRules.Band


func _model() -> SuspicionModel:
	return SuspicionModel.new(PROFILE)


# --- Bands and factors -------------------------------------------------------------------------------

func test_bands_follow_the_design_table() -> void:
	assert_int(SuspicionRules.band_of(0.0)).is_equal(Band.NORMAL)
	assert_int(SuspicionRules.band_of(19.9)).is_equal(Band.NORMAL)
	assert_int(SuspicionRules.band_of(20.0)).is_equal(Band.CURIOUS)
	assert_int(SuspicionRules.band_of(40.0)).is_equal(Band.SUSPICIOUS)
	assert_int(SuspicionRules.band_of(60.0)).is_equal(Band.SEARCHING)
	assert_int(SuspicionRules.band_of(80.0)).is_equal(Band.COMBAT)
	assert_int(SuspicionRules.band_of(100.0)).is_equal(Band.COMBAT)


func test_distance_factor_is_full_up_close_and_015_at_max_range() -> void:
	assert_float(SuspicionRules.distance_factor(2.0, 35.0)).is_equal(1.0)
	assert_float(SuspicionRules.distance_factor(5.0, 35.0)).is_equal(1.0)
	assert_float(SuspicionRules.distance_factor(20.0, 35.0)).is_equal_approx(0.575, 0.0001)
	assert_float(SuspicionRules.distance_factor(35.0, 35.0)).is_equal_approx(0.15, 0.0001)


func test_light_factor_runs_from_01_to_1() -> void:
	assert_float(SuspicionRules.light_factor(0.0)).is_equal_approx(0.1, 0.0001)
	assert_float(SuspicionRules.light_factor(0.5)).is_equal_approx(0.55, 0.0001)
	assert_float(SuspicionRules.light_factor(1.0)).is_equal_approx(1.0, 0.0001)


func test_stance_motion_cone_and_state_factors() -> void:
	assert_float(SuspicionRules.stance_factor(false)).is_equal(1.0)
	assert_float(SuspicionRules.stance_factor(true)).is_equal(0.6)
	assert_float(SuspicionRules.motion_factor(Motion.STILL)).is_equal(0.5)
	assert_float(SuspicionRules.motion_factor(Motion.WALK)).is_equal(1.0)
	assert_float(SuspicionRules.motion_factor(Motion.SPRINT)).is_equal(1.6)
	assert_float(SuspicionRules.cone_factor(Cone.PRIMARY)).is_equal(1.0)
	assert_float(SuspicionRules.cone_factor(Cone.PERIPHERAL)).is_equal(0.4)
	assert_float(SuspicionRules.state_factor(GuardState.PATROL)).is_equal(1.0)
	assert_float(SuspicionRules.state_factor(GuardState.INVESTIGATE)).is_equal(1.5)
	assert_float(SuspicionRules.state_factor(GuardState.SEARCH)).is_equal(1.5)
	assert_float(SuspicionRules.state_factor(GuardState.COMBAT)).is_equal(3.0)


func test_full_sight_rate_is_the_base_rate() -> void:
	var rate: float = SuspicionRules.sight_gain_per_second(PROFILE, 1.0, 5.0, 1.0, false, Motion.WALK, Cone.PRIMARY, GuardState.PATROL)
	assert_float(rate).is_equal_approx(PROFILE.sight_base_rate, 0.0001)


func test_sight_rate_multiplies_every_factor() -> void:
	# 45 × 1.0 (visibility) × 0.575 (20 m) × 0.55 (half lit) × 0.6 (crouched) × 0.5 (still) × 1 × 1
	var rate: float = SuspicionRules.sight_gain_per_second(PROFILE, 1.0, 20.0, 0.5, true, Motion.STILL, Cone.PRIMARY, GuardState.PATROL)
	assert_float(rate).is_equal_approx(4.269375, 0.001)


func test_partial_visibility_scales_the_rate() -> void:
	var full: float = SuspicionRules.sight_gain_per_second(PROFILE, 1.0, 5.0, 1.0, false, Motion.WALK, Cone.PRIMARY, GuardState.PATROL)
	var head_only: float = SuspicionRules.sight_gain_per_second(PROFILE, 1.0 / 3.0, 5.0, 1.0, false, Motion.WALK, Cone.PRIMARY, GuardState.PATROL)
	assert_float(head_only).is_equal_approx(full / 3.0, 0.001)


func test_instant_detection_needs_close_clear_and_lit() -> void:
	assert_bool(SuspicionRules.is_instant_detection(PROFILE, 1.0, 2.5, 0.8)).is_true()
	assert_bool(SuspicionRules.is_instant_detection(PROFILE, 0.67, 3.0, 0.3)).is_true()
	assert_bool(SuspicionRules.is_instant_detection(PROFILE, 1.0, 3.1, 0.8)).is_false()
	assert_bool(SuspicionRules.is_instant_detection(PROFILE, 0.33, 2.0, 0.8)).is_false()
	assert_bool(SuspicionRules.is_instant_detection(PROFILE, 1.0, 2.0, 0.29)).is_false()


# --- SuspicionModel ----------------------------------------------------------------------------------

func test_sight_accumulates_over_the_sighting_time() -> void:
	var model: SuspicionModel = _model()
	model.add_sight(1.0, 5.0, 1.0, false, Motion.WALK, Cone.PRIMARY, GuardState.PATROL, 0.5)
	assert_float(model.value).is_equal_approx(22.5, 0.01)


func test_instant_detection_sets_100() -> void:
	var model: SuspicionModel = _model()
	model.add_sight(1.0, 2.0, 1.0, false, Motion.WALK, Cone.PRIMARY, GuardState.PATROL, 0.1)
	assert_float(model.value).is_equal(100.0)


func test_value_never_exceeds_100() -> void:
	var model: SuspicionModel = _model()
	for i: int in 20:
		model.add_sight(1.0, 6.0, 1.0, false, Motion.SPRINT, Cone.PRIMARY, GuardState.COMBAT, 1.0)
	assert_float(model.value).is_equal(100.0)


func test_not_seeing_changes_nothing() -> void:
	var model: SuspicionModel = _model()
	model.update(2.0)
	model.add_sight(0.0, 5.0, 1.0, false, Motion.WALK, Cone.PRIMARY, GuardState.PATROL, 1.0)
	assert_float(model.value).is_equal(0.0)
	assert_float(model.seconds_since_stimulus).is_equal_approx(2.0, 0.0001)


func test_footsteps_add_10_but_never_pass_45() -> void:
	var model: SuspicionModel = _model()
	model.add_noise(NoiseEvent.FOOTSTEP_WALK)
	assert_float(model.value).is_equal(10.0)
	for i: int in 10:
		model.add_noise(NoiseEvent.FOOTSTEP_SPRINT)
	assert_float(model.value).is_equal(45.0)


func test_footsteps_do_not_lower_a_higher_value() -> void:
	var model: SuspicionModel = _model()
	model.set_value(60.0)
	model.add_noise(NoiseEvent.LANDING)
	assert_float(model.value).is_equal(60.0)


func test_landings_and_doors_count_like_footsteps() -> void:
	var model: SuspicionModel = _model()
	model.add_noise(NoiseEvent.LANDING)
	model.add_noise(NoiseEvent.DOOR)
	assert_float(model.value).is_equal(20.0)


func test_suppressed_shots_and_impacts_add_35() -> void:
	var model: SuspicionModel = _model()
	model.add_noise(NoiseEvent.SHOT_SUPPRESSED)
	assert_float(model.value).is_equal(35.0)
	model.add_noise(NoiseEvent.IMPACT)
	assert_float(model.value).is_equal(70.0)


func test_unsuppressed_shot_sets_at_least_80() -> void:
	var model: SuspicionModel = _model()
	model.set_value(10.0)
	model.add_noise(NoiseEvent.SHOT)
	assert_float(model.value).is_equal(80.0)
	model.set_value(95.0)
	model.add_noise(NoiseEvent.SHOT)
	assert_float(model.value).is_equal(95.0)


func test_damage_sets_100() -> void:
	var model: SuspicionModel = _model()
	model.on_damage()
	assert_float(model.value).is_equal(100.0)


func test_no_decay_for_three_seconds_then_8_per_second() -> void:
	var model: SuspicionModel = _model()
	model.set_value(25.0)
	model.add_noise(NoiseEvent.SHOT_SUPPRESSED)  # 60, and starts the quiet period
	for i: int in 25:
		model.update(0.1)
	assert_float(model.value).is_equal_approx(60.0, 0.001)
	for i: int in 25:
		model.update(0.1)
	# 5.0 s in: decaying for about 2.0 s at 8 per second.
	assert_float(model.value).is_equal_approx(44.0, 1.0)


func test_a_new_stimulus_restarts_the_quiet_period() -> void:
	var model: SuspicionModel = _model()
	model.set_value(50.0)
	model.update(2.9)
	model.add_noise(NoiseEvent.DOOR)  # too quiet to add anything at 50, but it is still a stimulus
	model.update(2.9)
	# Without the restart, 5.8 s would have cost about 22 points.
	assert_float(model.value).is_equal_approx(50.0, 0.001)


func test_decay_stops_at_zero() -> void:
	var model: SuspicionModel = _model()
	model.set_value(20.0)
	model.update(3.0)
	model.update(60.0)
	assert_float(model.value).is_equal(0.0)


func test_floor_holds_suspicion_up_until_it_expires() -> void:
	var model: SuspicionModel = _model()
	model.raise_floor(10.0, 100.0)
	model.set_value(50.0)
	model.update(3.0)
	model.update(10.0)
	assert_float(model.value).is_equal(10.0)
	model.update(200.0)
	assert_float(model.value).is_equal(0.0)


func test_permanent_floor_never_expires() -> void:
	var model: SuspicionModel = _model()
	model.raise_floor(30.0, -1.0)
	model.set_value(90.0)
	model.update(3.0)
	model.update(10000.0)
	assert_float(model.value).is_equal(30.0)


func test_a_lower_floor_does_not_replace_a_higher_one() -> void:
	var model: SuspicionModel = _model()
	model.raise_floor(30.0, -1.0)
	model.raise_floor(10.0, 5.0)
	assert_float(model.floor_value).is_equal(30.0)


func test_band_changes_are_announced_once() -> void:
	var model: SuspicionModel = _model()
	var changes: Array[String] = []
	model.band_changed.connect(func(old_band: Band, new_band: Band) -> void: changes.append("%d>%d" % [old_band, new_band]))
	model.set_value(10.0)
	model.set_value(25.0)
	model.set_value(30.0)
	model.set_value(85.0)
	assert_array(changes).is_equal(["0>1", "1>4"])


# --- PerceptionRules ---------------------------------------------------------------------------------

func test_primary_cone_is_100_degrees_and_35_metres() -> void:
	assert_int(PerceptionRules.classify(PROFILE, 10.0, 0.0, 20.0)).is_equal(Cone.PRIMARY)
	assert_int(PerceptionRules.classify(PROFILE, 49.0, 0.0, 35.0)).is_equal(Cone.PRIMARY)
	assert_int(PerceptionRules.classify(PROFILE, 10.0, 0.0, 36.0)).is_equal(Cone.NONE)


func test_peripheral_cone_is_wide_but_short() -> void:
	assert_int(PerceptionRules.classify(PROFILE, 51.0, 0.0, 8.0)).is_equal(Cone.PERIPHERAL)
	assert_int(PerceptionRules.classify(PROFILE, 79.0, 0.0, 10.0)).is_equal(Cone.PERIPHERAL)
	assert_int(PerceptionRules.classify(PROFILE, 79.0, 0.0, 11.0)).is_equal(Cone.NONE)
	assert_int(PerceptionRules.classify(PROFILE, 81.0, 0.0, 5.0)).is_equal(Cone.NONE)


func test_looking_too_far_up_or_down_sees_nothing() -> void:
	assert_int(PerceptionRules.classify(PROFILE, 0.0, 49.0, 5.0)).is_equal(Cone.PRIMARY)
	assert_int(PerceptionRules.classify(PROFILE, 0.0, 51.0, 5.0)).is_equal(Cone.NONE)


func test_update_interval_by_distance() -> void:
	assert_float(PerceptionRules.update_interval(5.0, false)).is_equal(0.1)
	assert_float(PerceptionRules.update_interval(14.9, false)).is_equal(0.1)
	assert_float(PerceptionRules.update_interval(15.0, false)).is_equal(0.2)
	assert_float(PerceptionRules.update_interval(39.9, false)).is_equal(0.2)
	assert_float(PerceptionRules.update_interval(40.0, false)).is_equal(1.0)


func test_combat_always_checks_at_10_hz() -> void:
	assert_float(PerceptionRules.update_interval(80.0, true)).is_equal(0.1)


func test_motion_classes() -> void:
	assert_int(PerceptionRules.motion_of(0.1, false)).is_equal(Motion.STILL)
	assert_int(PerceptionRules.motion_of(1.7, false)).is_equal(Motion.WALK)
	assert_int(PerceptionRules.motion_of(5.8, true)).is_equal(Motion.SPRINT)


func test_angles_between_facing_and_target() -> void:
	var facing: Vector3 = Vector3.FORWARD
	assert_float(PerceptionRules.horizontal_angle_deg(facing, Vector3(0, 0, -5))).is_equal_approx(0.0, 0.001)
	assert_float(PerceptionRules.horizontal_angle_deg(facing, Vector3(-3, 7, -3))).is_equal_approx(45.0, 0.001)
	assert_float(PerceptionRules.horizontal_angle_deg(facing, Vector3(2, 0, 2))).is_equal_approx(135.0, 0.001)
	assert_float(PerceptionRules.horizontal_angle_deg(facing, Vector3(0, 0, 5))).is_equal_approx(180.0, 0.001)
	assert_float(PerceptionRules.vertical_angle_deg(Vector3(3, -3, 0))).is_equal_approx(45.0, 0.001)
	assert_float(PerceptionRules.vertical_angle_deg(Vector3(0, 0, -4))).is_equal_approx(0.0, 0.001)
