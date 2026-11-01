extends GdUnitTestSuite
## Guard navigation, patrolling and dying, on a flat 40 m x 40 m navigation mesh.
## Steps are physics ticks (60 per second).

const GUARD_SCENE: PackedScene = preload("res://game/ai/guard/guard.tscn")
const ZONES: HitZoneTable = preload("res://data/damage/hit_zones.tres")
const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_suppressed.tres")

var _arena: Node3D
var _ballistics: BallisticsSystem


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)

	var navmesh: NavigationMesh = NavigationMesh.new()
	navmesh.vertices = PackedVector3Array([Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(20, 0, 20), Vector3(-20, 0, 20)])
	navmesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.navigation_mesh = navmesh
	_arena.add_child(region)

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(60.0, 1.0, 60.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_arena.add_child(floor_body)

	_ballistics = BallisticsSystem.new()
	_ballistics.hit_zones = ZONES
	_arena.add_child(_ballistics)
	await _ticks(5)


func test_walks_a_loop_in_order_and_wraps() -> void:
	var guard: Guard = _guard(_route(PatrolSequence.Mode.LOOP, [[-6, 0, 0.1], [6, 0, 0.1], [6, -8, 0.1]]))
	var visited: Array[int] = await _record_visited_points(guard, 2400, 5)
	assert_array(visited.slice(0, 5)).is_equal([0, 1, 2, 0, 1])


func test_ping_pong_turns_around_at_the_end() -> void:
	var guard: Guard = _guard(_route(PatrolSequence.Mode.PING_PONG, [[-6, 0, 0.1], [4, 0, 0.1], [4, -8, 0.1]]))
	var visited: Array[int] = await _record_visited_points(guard, 2400, 5)
	assert_array(visited.slice(0, 5)).is_equal([0, 1, 2, 1, 0])


func test_walks_at_patrol_speed() -> void:
	var guard: Guard = _guard(_route(PatrolSequence.Mode.LOOP, [[-10, 0, 0.1], [10, 0, 5.0]]), Vector3.INF, 0.0)
	# The guard starts on the first point, waits briefly, then walks to the second.
	await _ticks(120)
	var before: Vector3 = guard.global_position
	await _ticks(60)
	var speed: float = guard.global_position.distance_to(before)
	assert_float(speed).is_equal_approx(guard.profile.patrol_speed, 0.1)


func test_waits_at_a_point_for_its_wait_time() -> void:
	var guard: Guard = _guard(_route(PatrolSequence.Mode.LOOP, [[-3, 0, 1.0], [3, 0, 1.0]]))
	# Count the ticks spent waiting at the second point.
	var waiting_ticks: int = 0
	for i: int in 900:
		await get_tree().physics_frame
		var patrol: GuardPatrolState = guard.brain.current_state as GuardPatrolState
		if patrol.phase == GuardPatrolState.Phase.WAITING and patrol.point_index == 1:
			waiting_ticks += 1
		elif waiting_ticks > 0:
			break
	assert_int(waiting_ticks).is_between(58, 64)


func test_faces_a_look_direction_while_waiting() -> void:
	# Yaw 90 looks along -X.
	var route: PatrolRoute = _route(PatrolSequence.Mode.LOOP, [[-3, 0, 0.5], [3, 0, 2.0]])
	var second: PatrolPoint = route.points()[1]
	second.use_look_direction = true
	second.look_yaw_deg = 90.0
	var guard: Guard = _guard(route)
	var faced: bool = false
	# Walking from the first point to the second, the guard faces +X, so facing -X means it turned.
	for i: int in 1200:
		await get_tree().physics_frame
		var patrol: GuardPatrolState = guard.brain.current_state as GuardPatrolState
		if patrol.phase == GuardPatrolState.Phase.WAITING and patrol.point_index == 1 and guard.is_facing(Vector3.LEFT, 10.0):
			faced = true
			break
	assert_bool(faced).is_true()


func test_skips_a_point_that_is_off_the_navigation_mesh() -> void:
	var guard: Guard = _guard(_route(PatrolSequence.Mode.LOOP, [[0, 0, 0.1], [100, 0, 0.1], [4, 0, 0.1]]))
	var visited: Array[int] = await _record_visited_points(guard, 900, 3)
	assert_array(visited.slice(0, 3)).is_equal([0, 1, 2])
	# It did not wander toward the unreachable point.
	assert_float(guard.global_position.x).is_less(20.0)


func test_a_curious_guard_slows_down_looks_at_the_noise_then_recovers() -> void:
	var guard: Guard = _guard(_route(PatrolSequence.Mode.LOOP, [[-15, 0, 0.1], [15, 0, 0.1]]), Vector3.INF, 0.0)
	await _ticks(90)
	var normal_speed: float = Vector2(guard.velocity.x, guard.velocity.z).length()
	assert_float(normal_speed).is_equal_approx(guard.profile.patrol_speed, 0.1)

	# Three footsteps off to the side: suspicion 30, which is Curious.
	var noise_at: Vector3 = guard.global_position + Vector3(0.0, 0.0, 6.0)
	for i: int in 3:
		NoiseSystem.emit_noise(NoiseEvent.FOOTSTEP_SPRINT, noise_at, 12.0)
	assert_int(guard.suspicion.band).is_equal(SuspicionRules.Band.CURIOUS)
	await _ticks(45)
	var curious_speed: float = Vector2(guard.velocity.x, guard.velocity.z).length()
	assert_float(curious_speed).is_equal_approx(guard.profile.patrol_speed * guard.profile.curious_speed_factor, 0.1)
	assert_bool(guard.is_facing(noise_at - guard.global_position, 25.0)).is_true()

	# After the quiet period suspicion decays below 20 and the guard walks normally again.
	await _ticks(420)
	assert_int(guard.suspicion.band).is_equal(SuspicionRules.Band.NORMAL)
	var recovered_speed: float = Vector2(guard.velocity.x, guard.velocity.z).length()
	assert_float(recovered_speed).is_equal_approx(guard.profile.patrol_speed, 0.1)


func test_guard_without_a_route_stands_still() -> void:
	var guard: Guard = _guard(null)
	var start: Vector3 = guard.global_position
	await _ticks(120)
	assert_float(guard.global_position.distance_to(start)).is_less(0.05)


func test_dying_stops_the_guard_and_announces_the_state_change() -> void:
	var guard: Guard = _guard(_route(PatrolSequence.Mode.LOOP, [[-6, 0, 0.1], [6, 0, 0.1]]))
	var changes: Array[String] = []
	var on_change: Callable = func(g: Node, old_state: StringName, new_state: StringName) -> void:
		if g == guard:
			changes.append("%s>%s" % [old_state, new_state])
	EventBus.guard_state_changed.connect(on_change)
	await _ticks(60)
	var info: DamageInfo = DamageInfo.new()
	info.amount = 500.0
	guard.health.apply_damage(info)
	await _ticks(2)
	var resting: Vector3 = guard.global_position
	await _ticks(120)
	EventBus.guard_state_changed.disconnect(on_change)
	assert_bool(guard.is_dead).is_true()
	assert_array(changes).contains(["patrol>dead"])
	assert_float(guard.global_position.distance_to(resting)).is_less(0.01)
	assert_int(guard.collision_layer).is_equal(0)


func test_headshot_kills_and_torso_needs_three_hits() -> void:
	var head_guard: Guard = _guard(null, Vector3(-4.0, 0.0, 0.0))
	var torso_guard: Guard = _guard(null, Vector3(4.0, 0.0, 0.0))
	await _ticks(5)
	_ballistics.fire(Vector3(-4.0, 1.62, 6.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(20)
	assert_bool(head_guard.is_dead).is_true()
	for i: int in 2:
		_ballistics.fire(Vector3(4.0, 1.19, 6.0), Vector3.FORWARD, RIFLE, null)
		await _ticks(20)
	assert_bool(torso_guard.is_dead).is_false()
	_ballistics.fire(Vector3(4.0, 1.19, 6.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(20)
	assert_bool(torso_guard.is_dead).is_true()


func test_dead_guard_does_not_stop_bullets() -> void:
	var front: Guard = _guard(null, Vector3(0.0, 0.0, 0.0))
	var behind: Guard = _guard(null, Vector3(0.0, 0.0, -3.0))
	var info: DamageInfo = DamageInfo.new()
	info.amount = 500.0
	front.health.apply_damage(info)
	await _ticks(5)
	_ballistics.fire(Vector3(0.0, 1.62, 8.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(30)
	assert_bool(behind.is_dead).is_true()


## Walks the guard for up to max_ticks and returns the distinct patrol points it headed for, in order.
func _record_visited_points(guard: Guard, max_ticks: int, wanted: int) -> Array[int]:
	var visited: Array[int] = []
	for i: int in max_ticks:
		await get_tree().physics_frame
		var patrol: GuardPatrolState = guard.brain.current_state as GuardPatrolState
		if patrol != null and patrol.phase != GuardPatrolState.Phase.WAIT_FOR_NAVIGATION:
			if visited.is_empty() or visited[visited.size() - 1] != patrol.point_index:
				visited.append(patrol.point_index)
				if visited.size() >= wanted:
					break
	return visited


func _route(mode: PatrolSequence.Mode, points: Array) -> PatrolRoute:
	var route: PatrolRoute = PatrolRoute.new()
	route.mode = mode
	_arena.add_child(route)
	for entry: Array in points:
		var point: PatrolPoint = PatrolPoint.new()
		point.wait_time = float(entry[2])
		point.position = Vector3(float(entry[0]), 0.0, float(entry[1]))
		route.add_child(point)
	return route


## `speed` replaces the profile's patrol speed to keep tests short; 0 keeps the real value.
func _guard(route: PatrolRoute, position: Vector3 = Vector3.INF, speed: float = 5.0) -> Guard:
	var guard: Guard = GUARD_SCENE.instantiate()
	guard.guard_id = &"test_guard"
	if speed > 0.0:
		guard.profile = guard.profile.duplicate()
		guard.profile.patrol_speed = speed
	guard.patrol_route = route
	if position != Vector3.INF:
		guard.position = position
	elif route != null:
		guard.position = route.points()[0].position
	_arena.add_child(guard)
	return guard


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
