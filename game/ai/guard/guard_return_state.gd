class_name GuardReturnState
extends GuardState
## Walks back to the nearest point of the patrol route and resumes patrolling from there (design §7.4).

var _index: int = -1
var _stuck: StuckDetector = StuckDetector.new()


func enter(_previous: StringName) -> void:
	_index = -1
	var route: PatrolRoute = blackboard.patrol_route
	if route == null:
		return
	var points: Array[PatrolPoint] = route.points()
	var best: float = INF
	for i: int in points.size():
		var offset: Vector3 = points[i].global_position - guard.global_position
		offset.y = 0.0
		if offset.length_squared() < best:
			best = offset.length_squared()
			_index = i
	if _index >= 0:
		guard.navigate_to(points[_index].global_position)
		_stuck.reset(guard.global_position)


func exit() -> void:
	guard.stop()


func tick(delta: float) -> StringName:
	if _index < 0:
		return GuardState.PATROL
	var point: PatrolPoint = blackboard.patrol_route.points()[_index]
	if guard.is_at(point.global_position):
		return _resume_patrol()
	guard.move_along_path(guard.profile.return_speed)
	if not guard.is_target_reachable() or _stuck.update(guard.global_position, delta, guard.profile.stuck_min_progress_m, guard.profile.stuck_timeout_s):
		return _resume_patrol()
	return &""


func _resume_patrol() -> StringName:
	blackboard.patrol_index = _index
	return GuardState.PATROL
