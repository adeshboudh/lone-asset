extends GdUnitTestSuite
## Guard senses with real physics: line of sight, cover, lean, light, hearing, damage, and the
## scheduler's ray budget. The guard stands at the origin facing -Z (forward).

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")
const GUARD_SCENE: PackedScene = preload("res://game/ai/guard/guard.tscn")
const Cone := PerceptionRules.Cone

var _arena: Node3D
var _lighting: LevelLighting
var _player: Player
var _intent: InputIntent
var _guard: Guard
var _perception: PerceptionComponent


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	_lighting = LevelLighting.new()
	_lighting.ambient_light_level = 1.0
	_arena.add_child(_lighting)
	_add_box(Vector3(80.0, 1.0, 80.0), Vector3(0.0, -0.5, 0.0))
	_arena.add_child(BallisticsSystem.new())
	Log.min_level = Log.Level.ERROR  # guards without routes warn on every start
	PerceptionScheduler.max_rays_per_tick = 0


func after_test() -> void:
	Log.min_level = Log.Level.DEBUG if OS.is_debug_build() else Log.Level.INFO


# --- Line of sight ---------------------------------------------------------------------------------

func test_open_ground_shows_the_whole_player() -> void:
	await _spawn(Vector3(0.0, 0.0, -10.0))
	assert_float(_visibility()).is_equal(1.0)


func test_a_wall_hides_the_player() -> void:
	await _spawn(Vector3(0.0, 0.0, -10.0))
	_add_box(Vector3(6.0, 3.0, 0.4), Vector3(0.0, 1.5, -5.0))
	await _ticks(2)
	assert_float(_visibility()).is_equal(0.0)


func test_low_cover_shows_only_the_head_standing_and_nothing_crouched() -> void:
	await _spawn(Vector3(0.0, 0.0, -10.0))
	_add_box(Vector3(6.0, 1.5, 0.4), Vector3(0.0, 0.75, -5.0))
	await _ticks(2)
	assert_float(_visibility()).is_equal_approx(1.0 / 3.0, 0.01)
	_intent.crouch_toggled = true
	await _ticks(1)
	_intent.crouch_toggled = false
	await _ticks(30)
	assert_float(_visibility()).is_equal(0.0)


func test_leaning_around_a_pillar_exposes_only_the_head() -> void:
	await _spawn(Vector3(0.0, 0.0, -10.0))
	_add_box(Vector3(0.24, 3.0, 0.24), Vector3(0.0, 1.5, -5.0))
	await _ticks(2)
	assert_float(_visibility()).is_equal(0.0)
	_intent.lean = 1
	await _ticks(40)
	assert_float(_visibility()).is_equal_approx(1.0 / 3.0, 0.01)


# --- Vision cones ----------------------------------------------------------------------------------

func test_a_player_in_view_raises_suspicion_at_the_expected_rate() -> void:
	# Still, standing, 8 m away, fully lit: about 45 × 0.976 × 0.5 = 22 per second.
	await _spawn(Vector3(0.0, 0.0, -8.0))
	await _ticks(120)
	assert_float(_guard.suspicion.value).is_between(35.0, 52.0)
	assert_str(String(_guard.brain.blackboard.alerted_by)).is_equal("sight")


func test_a_walking_player_in_full_light_is_spotted_within_two_and_a_half_seconds() -> void:
	# Design acceptance: standing, moving, lit, about 10 m, in the primary cone.
	await _spawn(Vector3(-3.0, 0.0, -10.0))
	_intent.move = Vector2(1.0, 0.0)  # strafe right at walking speed, staying around 10 m away
	await _ticks(60)
	assert_float(_guard.suspicion.value).is_less(80.0)
	await _ticks(90)
	assert_float(_guard.suspicion.value).is_greater_equal(80.0)


func test_a_crouched_still_player_in_the_dark_is_not_detected_at_15m() -> void:
	# Design acceptance: crouched, still, dark volume, 15 m, suspicion stays below 40.
	await _spawn(Vector3(0.0, 0.0, -15.0))
	var dark: LightVolume = LightVolume.new()
	dark.light_level = 0.1
	dark.light_priority = 1
	dark.size = Vector3(8.0, 3.0, 8.0)
	dark.position = Vector3(0.0, 1.0, -15.0)
	_arena.add_child(dark)
	_intent.crouch_toggled = true
	await _ticks(1)
	_intent.crouch_toggled = false
	await _ticks(300)
	assert_float(_player.exposure.exposure).is_equal_approx(0.1, 0.001)
	assert_float(_guard.suspicion.value).is_greater(0.5)
	assert_float(_guard.suspicion.value).is_less(40.0)


func test_a_player_behind_the_guard_is_not_seen() -> void:
	await _spawn(Vector3(0.0, 0.0, 3.0))
	await _ticks(60)
	assert_float(_guard.suspicion.value).is_equal(0.0)
	assert_int(_perception.last_cone).is_equal(Cone.NONE)


func test_peripheral_vision_catches_a_close_player_off_to_the_side() -> void:
	# 70° off the facing direction, 8 m away: outside the 100° primary cone, inside the 160° peripheral one.
	await _spawn(Vector3(sin(deg_to_rad(70.0)) * 8.0, 0.0, -cos(deg_to_rad(70.0)) * 8.0))
	await _ticks(30)
	assert_int(_perception.last_cone).is_equal(Cone.PERIPHERAL)
	assert_float(_guard.suspicion.value).is_greater(0.0)


func test_peripheral_vision_does_not_reach_far() -> void:
	await _spawn(Vector3(sin(deg_to_rad(70.0)) * 15.0, 0.0, -cos(deg_to_rad(70.0)) * 15.0))
	await _ticks(60)
	assert_int(_perception.last_cone).is_equal(Cone.NONE)
	assert_float(_guard.suspicion.value).is_equal(0.0)


func test_close_lit_player_is_detected_instantly() -> void:
	await _spawn(Vector3(0.0, 0.0, -2.5))
	await _ticks(20)
	assert_float(_guard.suspicion.value).is_equal(100.0)


func test_close_player_in_deep_shadow_is_not_instant() -> void:
	_lighting.ambient_light_level = 0.2
	await _spawn(Vector3(0.0, 0.0, -2.5))
	await _ticks(20)
	assert_float(_guard.suspicion.value).is_less(100.0)


# --- Hearing, damage, death --------------------------------------------------------------------------

func test_a_suppressed_shot_nearby_adds_35_and_marks_where_it_came_from() -> void:
	await _spawn(Vector3(0.0, 0.0, 30.0))
	var source: Vector3 = Vector3(0.0, 0.0, -6.0)
	NoiseSystem.emit_noise(NoiseEvent.SHOT_SUPPRESSED, source, 18.0)
	assert_float(_guard.suspicion.value).is_equal(35.0)
	assert_bool(_guard.has_stimulus()).is_true()
	assert_vector(_guard.stimulus_position()).is_equal(source)
	assert_str(String(_guard.brain.blackboard.alerted_by)).is_equal("noise")


func test_footsteps_alone_never_push_a_guard_past_45() -> void:
	await _spawn(Vector3(0.0, 0.0, 30.0))
	for i: int in 12:
		NoiseSystem.emit_noise(NoiseEvent.FOOTSTEP_WALK, Vector3(2.0, 0.0, 0.0), 4.0)
	assert_float(_guard.suspicion.value).is_equal(45.0)


func test_an_unsuppressed_shot_is_heard_far_away_and_sets_80() -> void:
	await _spawn(Vector3(0.0, 0.0, 30.0))
	NoiseSystem.emit_noise(NoiseEvent.SHOT, Vector3(0.0, 0.0, -60.0), 80.0)
	assert_float(_guard.suspicion.value).is_equal(80.0)


func test_noise_out_of_range_is_not_heard() -> void:
	await _spawn(Vector3(0.0, 0.0, 30.0))
	NoiseSystem.emit_noise(NoiseEvent.SHOT_SUPPRESSED, Vector3(0.0, 0.0, -30.0), 18.0)
	assert_float(_guard.suspicion.value).is_equal(0.0)


func test_a_wall_muffles_a_noise_for_the_guard() -> void:
	await _spawn(Vector3(0.0, 0.0, 30.0))
	_add_box(Vector3(10.0, 3.0, 0.4), Vector3(0.0, 1.5, -3.0))
	await _ticks(2)
	# 12 m away, 18 m radius, one wall: 9 m effective, so not heard.
	NoiseSystem.emit_noise(NoiseEvent.SHOT_SUPPRESSED, Vector3(0.0, 0.0, -12.0), 18.0)
	assert_float(_guard.suspicion.value).is_equal(0.0)


func test_being_hit_sets_100_and_remembers_the_attacker() -> void:
	await _spawn(Vector3(0.0, 0.0, 30.0))
	var info: DamageInfo = DamageInfo.new()
	info.amount = 10.0
	info.source = _player
	_guard.health.apply_damage(info)
	assert_float(_guard.suspicion.value).is_equal(100.0)
	assert_str(String(_guard.brain.blackboard.alerted_by)).is_equal("damage")
	assert_vector(_guard.brain.blackboard.last_known_position).is_equal(_player.global_position)


func test_a_dead_guard_stops_looking() -> void:
	await _spawn(Vector3(0.0, 0.0, -10.0))
	var info: DamageInfo = DamageInfo.new()
	info.amount = 500.0
	_guard.health.apply_damage(info)
	await _ticks(5)
	var checks: int = _perception.checks_done
	await _ticks(60)
	assert_int(_perception.checks_done).is_equal(checks)


# --- Vision checks are paced -------------------------------------------------------------------------

func test_a_guard_within_15m_checks_about_ten_times_a_second() -> void:
	await _spawn(Vector3(0.0, 0.0, -10.0))
	var before: int = _perception.checks_done
	await _ticks(120)
	assert_int(_perception.checks_done - before).is_between(18, 22)


func test_a_distant_guard_checks_about_once_a_second() -> void:
	await _spawn(Vector3(0.0, 0.0, -50.0))
	var before: int = _perception.checks_done
	await _ticks(180)
	assert_int(_perception.checks_done - before).is_between(2, 4)


func test_many_guards_never_exceed_the_ray_budget_and_all_get_checks() -> void:
	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	var guards: Array[Guard] = []
	for i: int in 60:
		var guard: Guard = GUARD_SCENE.instantiate()
		guard.guard_id = StringName("crowd_%d" % i)
		var angle: float = TAU * i / 60.0
		guard.position = Vector3(cos(angle), 0.0, sin(angle)) * 10.0
		# Face the player in the middle so every check costs its full 3 rays.
		guard.rotation.y = atan2(guard.position.x, guard.position.z)
		_arena.add_child(guard)
		guards.append(guard)
	await _ticks(10)
	PerceptionScheduler.max_rays_per_tick = 0
	var before: Array[int] = []
	for guard: Guard in guards:
		before.append((guard.get_node("%PerceptionComponent") as PerceptionComponent).checks_done)
	await _ticks(120)
	assert_int(PerceptionScheduler.max_rays_per_tick).is_less_equal(PerceptionScheduler.RAY_BUDGET)
	assert_int(PerceptionScheduler.max_rays_per_tick).is_greater(PerceptionScheduler.RAY_BUDGET - 4)
	for i: int in guards.size():
		var done: int = (guards[i].get_node("%PerceptionComponent") as PerceptionComponent).checks_done - before[i]
		assert_int(done).override_failure_message("guard %d was checked only %d times in 2 s" % [i, done]).is_greater_equal(8)


# --- Helpers -----------------------------------------------------------------------------------------

func _spawn(player_position: Vector3) -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = player_position
	_arena.add_child(_player)
	_intent = InputIntent.new()
	_player.set_scripted_intent(_intent)
	_guard = GUARD_SCENE.instantiate()
	_guard.guard_id = &"test_guard"
	_arena.add_child(_guard)
	_perception = _guard.get_node("%PerceptionComponent")
	await _ticks(8)
	# Start each test from a calm guard; spawning settles physics for a few ticks.
	_guard.suspicion.set_value(0.0)


func _visibility() -> float:
	return _perception.visibility_of(_player.perception_points(), _guard.eye_position())


func _add_box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = position
	_arena.add_child(body)
	return body


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
