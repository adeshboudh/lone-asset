extends GdUnitTestSuite
## GuardAlertRules, AimRules, SearchPlanner geometry, ScanRules and StuckDetector (pure logic).

const PROFILE: GuardProfile = preload("res://data/ai/guard_default.tres")
const Band := SuspicionRules.Band


# --- GuardAlertRules -------------------------------------------------------------------------------

func test_calm_guards_stay_calm_below_suspicious() -> void:
	for band: Band in [Band.NORMAL, Band.CURIOUS]:
		assert_str(GuardAlertRules.target_state(GuardState.PATROL, band, false)).is_equal("")
		assert_str(GuardAlertRules.target_state(GuardState.RETURN_TO_PATROL, band, false)).is_equal("")


func test_suspicious_sends_a_calm_guard_to_investigate() -> void:
	assert_str(GuardAlertRules.target_state(GuardState.PATROL, Band.SUSPICIOUS, false)).is_equal(GuardState.INVESTIGATE)
	assert_str(GuardAlertRules.target_state(GuardState.RETURN_TO_PATROL, Band.SUSPICIOUS, false)).is_equal(GuardState.INVESTIGATE)


func test_suspicious_changes_nothing_for_guards_already_alert() -> void:
	for state: StringName in [GuardState.INVESTIGATE, GuardState.SEARCH, GuardState.COMBAT]:
		assert_str(GuardAlertRules.target_state(state, Band.SUSPICIOUS, false)).is_equal("")


func test_searching_band_escalates_calm_and_investigating_guards_to_search() -> void:
	for state: StringName in [GuardState.PATROL, GuardState.RETURN_TO_PATROL, GuardState.INVESTIGATE]:
		assert_str(GuardAlertRules.target_state(state, Band.SEARCHING, false)).is_equal(GuardState.SEARCH)
	assert_str(GuardAlertRules.target_state(GuardState.SEARCH, Band.SEARCHING, false)).is_equal("")
	assert_str(GuardAlertRules.target_state(GuardState.COMBAT, Band.SEARCHING, false)).is_equal("")


func test_combat_band_with_contact_starts_a_fight_from_any_state() -> void:
	for state: StringName in [GuardState.PATROL, GuardState.RETURN_TO_PATROL, GuardState.INVESTIGATE, GuardState.SEARCH]:
		assert_str(GuardAlertRules.target_state(state, Band.COMBAT, true)).is_equal(GuardState.COMBAT)
	assert_str(GuardAlertRules.target_state(GuardState.COMBAT, Band.COMBAT, true)).is_equal("")


func test_combat_band_without_contact_means_a_combat_ready_search() -> void:
	for state: StringName in [GuardState.PATROL, GuardState.RETURN_TO_PATROL, GuardState.INVESTIGATE]:
		assert_str(GuardAlertRules.target_state(state, Band.COMBAT, false)).is_equal(GuardState.SEARCH)
	assert_str(GuardAlertRules.target_state(GuardState.SEARCH, Band.COMBAT, false)).is_equal("")
	assert_str(GuardAlertRules.target_state(GuardState.COMBAT, Band.COMBAT, false)).is_equal("")


func test_dead_guards_never_change_state() -> void:
	for band: Band in [Band.NORMAL, Band.SUSPICIOUS, Band.SEARCHING, Band.COMBAT]:
		assert_str(GuardAlertRules.target_state(GuardState.DEAD, band, true)).is_equal("")


# --- AimRules --------------------------------------------------------------------------------------

func test_aim_starts_wild_and_settles() -> void:
	assert_float(AimRules.error_deg(PROFILE, 0.0, 0.0)).is_equal(PROFILE.aim_error_start_deg)
	assert_float(AimRules.error_deg(PROFILE, PROFILE.aim_settle_s, 0.0)).is_equal(PROFILE.aim_error_min_deg)
	assert_float(AimRules.error_deg(PROFILE, PROFILE.aim_settle_s * 10.0, 0.0)).is_equal(PROFILE.aim_error_min_deg)
	var halfway: float = (PROFILE.aim_error_start_deg + PROFILE.aim_error_min_deg) * 0.5
	assert_float(AimRules.error_deg(PROFILE, PROFILE.aim_settle_s * 0.5, 0.0)).is_equal_approx(halfway, 0.0001)


func test_a_moving_target_is_harder_to_hit() -> void:
	var still: float = AimRules.error_deg(PROFILE, 1.0, 0.0)
	var moving: float = AimRules.error_deg(PROFILE, 1.0, 3.0)
	assert_float(moving).is_equal_approx(still * PROFILE.moving_target_error_mult, 0.0001)


# --- SearchPlanner geometry ------------------------------------------------------------------------

func test_far_enough_ignores_height() -> void:
	var existing: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0)]
	assert_bool(SearchPlanner.far_enough(Vector3(5, 3, 0), existing, 3.0)).is_true()
	assert_bool(SearchPlanner.far_enough(Vector3(1, 5, 1), existing, 3.0)).is_false()
	assert_bool(SearchPlanner.far_enough(Vector3(1, 0, 0), [] as Array[Vector3], 3.0)).is_true()


func test_tour_goes_to_the_nearest_unvisited_point_each_time() -> void:
	var points: Array[Vector3] = [Vector3(10, 0, 0), Vector3(2, 0, 0), Vector3(6, 0, 0), Vector3(-3, 0, 0)]
	var ordered: Array[Vector3] = SearchPlanner.order_nearest_first(Vector3.ZERO, points)
	assert_array(ordered).is_equal([Vector3(2, 0, 0), Vector3(6, 0, 0), Vector3(10, 0, 0), Vector3(-3, 0, 0)])
	assert_array(SearchPlanner.order_nearest_first(Vector3.ZERO, [] as Array[Vector3])).is_empty()


# --- ScanRules -------------------------------------------------------------------------------------

func test_scan_looks_ahead_then_left_then_right() -> void:
	var base: Vector3 = Vector3.FORWARD
	assert_vector(ScanRules.direction_at(base, 0.0, 1.0, 60.0)).is_equal_approx(base, Vector3.ONE * 0.0001)
	# Positive rotation about UP turns to the left.
	var left: Vector3 = ScanRules.direction_at(base, 1.1, 1.0, 60.0)
	assert_float(rad_to_deg(base.signed_angle_to(left, Vector3.UP))).is_equal_approx(60.0, 0.01)
	var right: Vector3 = ScanRules.direction_at(base, 2.1, 1.0, 60.0)
	assert_float(rad_to_deg(base.signed_angle_to(right, Vector3.UP))).is_equal_approx(-60.0, 0.01)


func test_scan_repeats_after_all_directions() -> void:
	var base: Vector3 = Vector3.FORWARD
	assert_vector(ScanRules.direction_at(base, 5.2, 1.0, 60.0)).is_equal_approx(base, Vector3.ONE * 0.0001)


# --- StuckDetector ---------------------------------------------------------------------------------

func test_progress_keeps_resetting_the_stuck_timer() -> void:
	var detector: StuckDetector = StuckDetector.new()
	detector.reset(Vector3.ZERO)
	var position: Vector3 = Vector3.ZERO
	for i: int in 100:
		position.x += 0.05
		assert_bool(detector.update(position, 0.1, 0.15, 2.5)).is_false()


func test_standing_still_is_stuck_after_the_timeout() -> void:
	var detector: StuckDetector = StuckDetector.new()
	detector.reset(Vector3.ZERO)
	var stuck: bool = false
	for i: int in 30:
		stuck = detector.update(Vector3(0.01, 0, 0), 0.1, 0.15, 2.5)
	assert_bool(stuck).is_true()
