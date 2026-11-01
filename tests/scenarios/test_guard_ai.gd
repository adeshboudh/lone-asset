extends GdUnitTestSuite
## The guard AI loop with real physics and bullets: investigate, search, fight, lose the player, give up.
## Guards use a "fast" copy of the default profile (shorter timers, higher speeds) to keep tests short;
## the sequence of states and the rules are the real ones.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")
const GUARD_SCENE: PackedScene = preload("res://game/ai/guard/guard.tscn")
const BASE_PROFILE: GuardProfile = preload("res://data/ai/guard_default.tres")
const ZONES: HitZoneTable = preload("res://data/damage/hit_zones.tres")

var _arena: Node3D
var _lighting: LevelLighting
var _player: Player
var _intent: InputIntent
var _changes: Array[String] = []
var _on_change: Callable
var _shots_heard: Array[NoiseEvent] = []
var _on_noise: Callable
var _guard_count: int = 0

## Further than any guard can see, for tests where the player should not matter.
const FAR_CORNER: Vector3 = Vector3(-38.0, 0.0, 38.0)


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	_lighting = LevelLighting.new()
	_lighting.ambient_light_level = 1.0
	_arena.add_child(_lighting)

	var navmesh: NavigationMesh = NavigationMesh.new()
	navmesh.vertices = PackedVector3Array([Vector3(-40, 0, -40), Vector3(40, 0, -40), Vector3(40, 0, 40), Vector3(-40, 0, 40)])
	navmesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.navigation_mesh = navmesh
	_arena.add_child(region)
	_add_box(Vector3(100.0, 1.0, 100.0), Vector3(0.0, -0.5, 0.0))

	var ballistics: BallisticsSystem = BallisticsSystem.new()
	ballistics.hit_zones = ZONES
	_arena.add_child(ballistics)

	Log.min_level = Log.Level.ERROR
	_guard_count = 0
	_changes.clear()
	_shots_heard.clear()
	_on_change = func(guard: Node, old_state: StringName, new_state: StringName) -> void:
		_changes.append("%s:%s>%s" % [(guard as Guard).guard_id, old_state, new_state])
	EventBus.guard_state_changed.connect(_on_change)
	_on_noise = func(event: NoiseEvent) -> void:
		if event.type == NoiseEvent.SHOT:
			_shots_heard.append(event)
	EventBus.noise_emitted.connect(_on_noise)
	await _ticks(5)


func after_test() -> void:
	EventBus.guard_state_changed.disconnect(_on_change)
	EventBus.noise_emitted.disconnect(_on_noise)
	Log.min_level = Log.Level.DEBUG if OS.is_debug_build() else Log.Level.INFO


# --- Investigating and searching -------------------------------------------------------------------

func test_footsteps_send_a_patrolling_guard_to_investigate_then_back_to_its_route() -> void:
	await _spawn_player(FAR_CORNER)
	var guard: Guard = _guard(Vector3(-10.0, 0.0, 0.0), _route([[-10, 0, 0.3], [10, 0, 0.3]]))
	await _ticks(60)
	var noise_at: Vector3 = guard.global_position + Vector3(0.0, 0.0, 6.0)
	for i: int in 4:
		NoiseSystem.emit_noise(NoiseEvent.FOOTSTEP_SPRINT, noise_at, 12.0)
	assert_float(guard.suspicion.value).is_equal(40.0)
	await _ticks(2)
	assert_str(guard.brain.current_name).is_equal("investigate")

	var closest: Array[float] = [INF]  # lambdas copy plain variables, so collect into an array
	var done: bool = await _wait_until(func() -> bool:
		closest[0] = minf(closest[0], Vector2(guard.global_position.x - noise_at.x, guard.global_position.z - noise_at.z).length())
		return guard.brain.current_name == GuardState.PATROL, 1500)
	assert_bool(done).is_true()
	assert_float(closest[0]).is_less(1.0)
	assert_array(_changes).contains(["guard:patrol>investigate", "guard:investigate>return_to_patrol", "guard:return_to_patrol>patrol"])


func test_two_suppressed_shots_make_a_guard_search_around_the_noise_then_give_up() -> void:
	await _spawn_player(FAR_CORNER)
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), _route([[0, 0, 0.3], [10, 0, 0.3]]))
	await _ticks(30)
	var noise_at: Vector3 = Vector3(5.0, 0.0, -6.0)
	NoiseSystem.emit_noise(NoiseEvent.SHOT_SUPPRESSED, noise_at, 18.0)
	NoiseSystem.emit_noise(NoiseEvent.SHOT_SUPPRESSED, noise_at, 18.0)
	await _ticks(2)
	assert_str(guard.brain.current_name).is_equal("search")
	assert_float(guard.suspicion.floor_value).is_equal(guard.profile.search_floor)

	var search: GuardSearchState = guard.brain.current_state as GuardSearchState
	var points: Array[Vector3] = search.points()
	assert_int(points.size()).is_between(guard.profile.search_points_min, guard.profile.search_points_max)
	assert_float(Vector2(points[0].x - noise_at.x, points[0].z - noise_at.z).length()).is_less(1.0)
	for point: Vector3 in points:
		assert_float(Vector2(point.x - noise_at.x, point.z - noise_at.z).length()).is_less_equal(guard.profile.search_radius_m + 0.1)

	var done: bool = await _wait_until(func() -> bool: return guard.brain.current_name == GuardState.PATROL, 2400)
	assert_bool(done).is_true()
	assert_array(_changes).contains(["guard:patrol>search", "guard:search>return_to_patrol", "guard:return_to_patrol>patrol"])


func test_gunfire_without_seeing_anyone_means_a_search_not_a_fight() -> void:
	await _spawn_player(FAR_CORNER)
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null)
	await _ticks(10)
	NoiseSystem.emit_noise(NoiseEvent.SHOT, Vector3(0.0, 0.0, -60.0), 80.0)
	await _ticks(2)
	assert_float(guard.suspicion.value).is_greater_equal(80.0)
	assert_str(guard.brain.current_name).is_equal("search")


func test_a_new_noise_far_from_the_search_moves_the_search() -> void:
	await _spawn_player(FAR_CORNER)
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null)
	await _ticks(10)
	NoiseSystem.emit_noise(NoiseEvent.SHOT, Vector3(0.0, 0.0, -20.0), 80.0)
	await _ticks(5)
	var search: GuardSearchState = guard.brain.current_state as GuardSearchState
	var first_centre: Vector3 = search.points()[0]
	NoiseSystem.emit_noise(NoiseEvent.SHOT, Vector3(25.0, 0.0, 10.0), 80.0)
	await _ticks(5)
	assert_float(Vector2(search.points()[0].x - 25.0, search.points()[0].z - 10.0).length()).is_less(1.0)
	assert_float(search.points()[0].distance_to(first_centre)).is_greater(10.0)


# --- Fighting ---------------------------------------------------------------------------------------

func test_a_guard_that_sees_the_player_fights_and_hurts_them() -> void:
	await _spawn_player(Vector3(0.0, 0.0, -8.0))
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null, _fast_profile())
	guard.profile.aim_error_start_deg = 1.0
	guard.profile.aim_error_min_deg = 1.0
	var fighting: bool = await _wait_until(func() -> bool: return guard.brain.current_name == GuardState.COMBAT, 600)
	assert_bool(fighting).is_true()
	var hurt: bool = await _wait_until(func() -> bool: return _player.health.health < 100.0, 600)
	assert_bool(hurt).is_true()
	assert_array(_shots_heard).is_not_empty()
	assert_float(_shots_heard[0].radius_m).is_equal(80.0)
	assert_int((guard.brain.current_state as GuardCombatState).phase).is_not_equal(GuardCombatState.Phase.CHASE)


func test_the_first_shot_comes_after_the_reaction_delay() -> void:
	await _spawn_player(Vector3(0.0, 0.0, -8.0))
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null, _fast_profile())
	guard.suspicion.on_damage()  # fight starts immediately, with contact
	guard.brain.blackboard.target = _player
	guard.brain.blackboard.last_contact_time = guard.time
	guard.brain.blackboard.last_sight_time = guard.time
	guard.brain.blackboard.last_known_position = _player.global_position
	var started_at: float = -1.0
	var first_shot_at: float = -1.0
	for i: int in 240:
		await get_tree().physics_frame
		guard.brain.blackboard.last_sight_time = guard.time  # keeps a clear view
		guard.brain.blackboard.last_contact_time = guard.time
		if started_at < 0.0 and guard.brain.current_name == GuardState.COMBAT:
			started_at = guard.time
		if started_at >= 0.0 and first_shot_at < 0.0 and not _shots_heard.is_empty():
			first_shot_at = guard.time
			break
	assert_float(started_at).is_greater_equal(0.0)
	assert_float(first_shot_at - started_at).is_greater_equal(guard.profile.reaction_delay_s - 0.05)


func test_a_guard_that_is_shot_remembers_the_shooter_and_fights() -> void:
	await _spawn_player(Vector3(0.0, 0.0, 20.0))  # behind the guard, out of sight
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null, _fast_profile())
	await _ticks(10)
	var info: DamageInfo = DamageInfo.new()
	info.amount = 10.0
	info.source = _player
	guard.health.apply_damage(info)
	await _ticks(3)
	assert_str(guard.brain.current_name).is_equal("combat")
	assert_vector(guard.brain.blackboard.last_known_position).is_equal(_player.global_position)
	# It cannot see the player, so it runs toward where the shot came from.
	assert_int((guard.brain.current_state as GuardCombatState).phase).is_equal(GuardCombatState.Phase.CHASE)
	await _ticks(60)
	assert_float(guard.global_position.z).is_greater(1.0)


func test_a_hurt_guard_in_a_fight_moves_to_a_new_firing_position() -> void:
	await _spawn_player(Vector3(0.0, 0.0, -10.0))
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null, _fast_profile())
	var fighting: bool = await _wait_until(func() -> bool:
		return guard.brain.current_name == GuardState.COMBAT and (guard.brain.current_state as GuardCombatState).phase == GuardCombatState.Phase.ENGAGE, 900)
	assert_bool(fighting).is_true()
	var start: Vector3 = guard.global_position
	var info: DamageInfo = DamageInfo.new()
	info.amount = 5.0
	info.source = _player
	guard.health.apply_damage(info)
	var moved: bool = await _wait_until(func() -> bool:
		return (guard.brain.current_state as GuardCombatState).phase == GuardCombatState.Phase.REPOSITION, 60)
	assert_bool(moved).is_true()
	await _ticks(90)
	assert_float(guard.global_position.distance_to(start)).is_greater(2.0)


func test_a_firing_position_has_a_clear_view_of_the_target() -> void:
	# A wall hides the target from the guard; any position the guard picks must see past it.
	_add_box(Vector3(14.0, 4.0, 0.5), Vector3(0.0, 2.0, -5.0))
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null, _fast_profile())
	guard.rng.seed = 7
	await _ticks(5)
	var target: Vector3 = Vector3(0.0, 1.2, -12.0)
	var space: PhysicsDirectSpaceState3D = guard.get_world_3d().direct_space_state
	assert_bool(space.intersect_ray(PhysicsRayQueryParameters3D.create(guard.eye_position(), target, PerceptionRules.LOS_MASK)).is_empty()).is_false()
	var found: int = 0
	for attempt: int in 12:
		var spot: Vector3 = guard.find_position_with_sight_of(target)
		if spot == Vector3.INF:
			continue
		found += 1
		var eye: Vector3 = Vector3(spot.x, guard.global_position.y + guard.profile.eye_height_m, spot.z)
		assert_bool(space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target, PerceptionRules.LOS_MASK)).is_empty()).is_true()
		assert_float(Vector2(spot.x, spot.z).length()).is_greater_equal(guard.profile.reposition_min_m - 0.1)
	assert_int(found).is_greater(0)


func test_losing_the_player_ends_the_fight_in_a_search() -> void:
	await _spawn_player(Vector3(0.0, 0.0, -8.0))
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null, _fast_profile())
	var fighting: bool = await _wait_until(func() -> bool: return guard.brain.current_name == GuardState.COMBAT, 600)
	assert_bool(fighting).is_true()
	# The player vanishes behind a wall, far from the guard and out of its view.
	_add_box(Vector3(10.0, 4.0, 0.5), Vector3(0.0, 2.0, 24.0))
	_player.global_position = Vector3(0.0, 0.1, 30.0)
	var chasing: bool = await _wait_until(func() -> bool:
		return guard.brain.current_name == GuardState.COMBAT and (guard.brain.current_state as GuardCombatState).phase == GuardCombatState.Phase.CHASE, 120)
	assert_bool(chasing).is_true()
	var searching: bool = await _wait_until(func() -> bool: return guard.brain.current_name == GuardState.SEARCH, 900)
	assert_bool(searching).is_true()
	assert_array(_changes).contains(["guard:combat>search"])
	assert_float(guard.suspicion.floor_value).is_greater_equal(guard.profile.combat_floor)


func test_after_a_fight_a_guard_stays_wary_for_good() -> void:
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null, _fast_profile())
	await _spawn_player(Vector3(0.0, 0.0, 30.0))
	guard.suspicion.on_damage()
	guard.brain.blackboard.target = _player
	guard.brain.blackboard.last_contact_time = guard.time
	guard.brain.blackboard.last_known_position = _player.global_position
	await _ticks(5)
	assert_str(guard.brain.current_name).is_equal("combat")
	guard.suspicion.update(1000.0)
	assert_float(guard.suspicion.value).is_equal(guard.profile.combat_floor)


func test_other_guards_hear_the_gunfire_and_come_searching() -> void:
	await _spawn_player(Vector3(0.0, 0.0, -6.0))
	var fighter: Guard = _guard(Vector3(0.0, 0.0, 0.0), null, _fast_profile())
	var listener: Guard = _guard(Vector3(35.0, 0.0, 35.0), null, _fast_profile())
	listener.rotation.y = PI  # facing away from the fight
	var searching: bool = await _wait_until(func() -> bool: return listener.brain.current_name == GuardState.SEARCH, 900)
	assert_bool(searching).is_true()
	assert_str(fighter.brain.current_name).is_equal("combat")
	assert_array(_changes).contains(["listener:patrol>search"])


func test_a_dead_player_ends_the_fight() -> void:
	await _spawn_player(Vector3(0.0, 0.0, -8.0))
	var guard: Guard = _guard(Vector3(0.0, 0.0, 0.0), null, _fast_profile())
	var fighting: bool = await _wait_until(func() -> bool: return guard.brain.current_name == GuardState.COMBAT, 600)
	assert_bool(fighting).is_true()
	var died: Array[bool] = [false]
	var on_died: Callable = func() -> void: died[0] = true
	EventBus.player_died.connect(on_died)
	var info: DamageInfo = DamageInfo.new()
	info.amount = 500.0
	_player.health.apply_damage(info)
	await _ticks(5)
	EventBus.player_died.disconnect(on_died)
	assert_bool(died[0]).is_true()
	assert_str(guard.brain.current_name).is_not_equal("combat")


# --- Helpers ---------------------------------------------------------------------------------------

## A copy of the default profile with short timers and fast legs, so tests do not take minutes.
func _fast_profile() -> GuardProfile:
	var p: GuardProfile = BASE_PROFILE.duplicate()
	p.patrol_speed = 4.0
	p.investigate_speed = 5.0
	p.search_speed = 5.0
	p.return_speed = 5.0
	p.run_speed = 6.0
	p.turn_to_stimulus_s = 0.3
	p.investigate_look_s = 1.0
	p.scan_step_s = 0.4
	p.search_scan_s = 0.6
	p.search_timeout_s = 4.0
	p.target_lost_s = 3.0
	p.decay_delay_s = 1.0
	# Decay must outpace the shortened search, as it does with the real 45 s timeout.
	p.decay_rate = 30.0
	p.reposition_interval_min_s = 2.0
	p.reposition_interval_max_s = 3.0
	return p


func _spawn_player(position: Vector3) -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = position
	_arena.add_child(_player)
	_intent = InputIntent.new()
	_player.set_scripted_intent(_intent)
	await _ticks(3)


func _guard(position: Vector3, route: PatrolRoute, profile: GuardProfile = null) -> Guard:
	var guard: Guard = GUARD_SCENE.instantiate()
	_guard_count += 1
	guard.guard_id = StringName("guard") if _guard_count == 1 else StringName("listener" if _guard_count == 2 else "g%d" % _guard_count)
	if profile == null:
		profile = _fast_profile()
	guard.profile = profile
	guard.patrol_route = route
	guard.position = position
	_arena.add_child(guard)
	if _guard_count == 1:
		guard.guard_id = &"guard"
	return guard


func _route(points: Array) -> PatrolRoute:
	var route: PatrolRoute = PatrolRoute.new()
	_arena.add_child(route)
	for entry: Array in points:
		var point: PatrolPoint = PatrolPoint.new()
		point.wait_time = float(entry[2])
		point.position = Vector3(float(entry[0]), 0.0, float(entry[1]))
		route.add_child(point)
	return route


## Ticks until `condition` is true; false if it never is within max_ticks.
func _wait_until(condition: Callable, max_ticks: int) -> bool:
	for i: int in max_ticks:
		await get_tree().physics_frame
		if condition.call():
			return true
	return false


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
