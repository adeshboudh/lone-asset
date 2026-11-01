extends GdUnitTestSuite
## The movement course's baked navigation mesh and its two patrolling guards.
## If a leg fails after the course geometry changed, re-bake: godot --headless --path . -s res://dev/bake_navmesh.gd

const COURSE: PackedScene = preload("res://game/levels/graybox/movement_course.tscn")

var _course: Node


func before_test() -> void:
	_course = COURSE.instantiate()
	add_child(_course)
	# The spawn point is on guard A's route and guards now attack what they see. These tests are about
	# patrolling, so the player is taken out; the fight itself is covered by test_guard_ai.gd.
	_course.get_node("Player").free()
	await _ticks(10)


func after_test() -> void:
	_course.queue_free()
	await get_tree().process_frame


func test_every_patrol_leg_is_connected_on_the_baked_mesh() -> void:
	var map: RID = _course.get_node("NavigationRegion").get_navigation_map()
	for route_name: String in ["RouteA", "RouteB", "RouteC"]:
		var points: Array[PatrolPoint] = (_course.get_node("Patrols/" + route_name) as PatrolRoute).points()
		assert_int(points.size()).override_failure_message("%s has no points" % route_name).is_greater(1)
		for i: int in points.size():
			var from: Vector3 = points[i].global_position
			var to: Vector3 = points[(i + 1) % points.size()].global_position
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
			assert_int(path.size()).override_failure_message("%s leg %d has no path" % [route_name, i]).is_greater(1)
			var end: Vector3 = path[path.size() - 1]
			var gap: float = Vector2(end.x - to.x, end.z - to.z).length()
			assert_float(gap).override_failure_message("%s leg %d ends %.2f m from its point" % [route_name, i, gap]).is_less(0.6)


func test_the_compound_can_be_entered_through_either_door() -> void:
	var map: RID = _course.get_node("NavigationRegion").get_navigation_map()
	var inside: Vector3 = Vector3(-23.0, 0.0, -24.0)
	for outside: Vector3 in [Vector3(-23.8, 0.0, -17.0), Vector3(-14.0, 0.0, -26.0)]:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, outside, inside, true)
		assert_int(path.size()).override_failure_message("no path from %s into the compound" % outside).is_greater(1)
		var end: Vector3 = path[path.size() - 1]
		assert_float(Vector2(end.x - inside.x, end.z - inside.z).length()).is_less(0.6)


func test_doors_sit_in_their_doorways_with_the_leaf_along_the_wall() -> void:
	var south: Door = _course.get_node("Compound/DoorSouth")
	var east: Door = _course.get_node("Compound/DoorEast")
	assert_vector(south.global_basis.x).is_equal_approx(Vector3.RIGHT, Vector3(0.01, 0.01, 0.01))
	# The east wall runs north-south, so that door's leaf runs along z.
	assert_float(absf(east.global_basis.x.z)).is_equal_approx(1.0, 0.01)
	assert_float(absf(east.global_basis.x.x)).is_less(0.01)


func test_guards_are_assigned_their_routes() -> void:
	assert_object(_course.get_node("Guards/GuardA").patrol_route).is_same(_course.get_node("Patrols/RouteA"))
	assert_object(_course.get_node("Guards/GuardB").patrol_route).is_same(_course.get_node("Patrols/RouteB"))


func test_both_guards_are_patrolling_and_moving() -> void:
	var guard_a: Guard = _course.get_node("Guards/GuardA")
	var guard_b: Guard = _course.get_node("Guards/GuardB")
	var start_a: Vector3 = guard_a.global_position
	var start_b: Vector3 = guard_b.global_position
	await _ticks(420)
	assert_str(guard_a.brain.current_name).is_equal("patrol")
	assert_str(guard_b.brain.current_name).is_equal("patrol")
	assert_float(guard_a.global_position.distance_to(start_a)).is_greater(2.0)
	assert_float(guard_b.global_position.distance_to(start_b)).is_greater(2.0)
	assert_bool(guard_a.is_on_floor()).is_true()


func test_guard_a_completes_a_lap_without_being_skipped_or_stuck() -> void:
	var guard: Guard = _course.get_node("Guards/GuardA")
	# A lap is about 50 m; run it fast with short waits to keep the test short.
	guard.profile = guard.profile.duplicate()
	guard.profile.patrol_speed = 5.0
	for point: PatrolPoint in guard.patrol_route.points():
		point.wait_time = 0.2
	var visited: Array[int] = []
	for i: int in 2400:
		await get_tree().physics_frame
		var patrol: GuardPatrolState = guard.brain.current_state as GuardPatrolState
		if patrol != null and (visited.is_empty() or visited[visited.size() - 1] != patrol.point_index):
			visited.append(patrol.point_index)
		if visited.size() >= 5:
			break
	assert_array(visited.slice(0, 5)).is_equal([0, 1, 2, 3, 0])


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
