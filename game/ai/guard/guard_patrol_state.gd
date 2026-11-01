class_name GuardPatrolState
extends GuardState
## Walks a PatrolRoute, waiting at each point (design §7.4).

enum Phase { WAIT_FOR_NAVIGATION, MOVING, WAITING }
## Facing a PatrolPoint's look direction within this many degrees counts as facing it.
const FACING_TOLERANCE_DEG: float = 8.0

var phase: Phase = Phase.WAIT_FOR_NAVIGATION
## Index of the point the guard is heading to or standing at.
var point_index: int:
	get:
		return _sequence.index if _sequence != null else 0

var _points: Array[PatrolPoint] = []
var _sequence: PatrolSequence
var _wait_remaining: float = 0.0
var _stuck_time: float = 0.0
var _stuck_reference: Vector3 = Vector3.ZERO


func enter(_previous: StringName) -> void:
	var route: PatrolRoute = blackboard.patrol_route
	_points.clear()
	if route != null:
		_points = route.points()
	if _points.is_empty():
		Log.warn(&"ai", "Guard '%s' has no patrol route; standing still" % guard.guard_id)
		return
	_sequence = PatrolSequence.new(_points.size(), route.mode, blackboard.patrol_index)
	_start_moving()


func exit() -> void:
	guard.stop()


func tick(delta: float) -> StringName:
	if _points.is_empty():
		guard.stop()
		return &""
	match phase:
		Phase.WAIT_FOR_NAVIGATION:
			guard.stop()
			if guard.navigation_ready():
				_start_moving()
		Phase.MOVING:
			_tick_moving(delta)
		Phase.WAITING:
			_tick_waiting(delta)
	return &""


func _tick_moving(delta: float) -> void:
	var point: PatrolPoint = _points[_sequence.index]
	if guard.is_at(point.global_position):
		_arrive(point)
		return
	guard.move_along_path(guard.profile.patrol_speed)
	if not guard.is_target_reachable():
		Log.warn(&"ai", "Guard '%s' cannot reach patrol point %d; skipping it" % [guard.guard_id, _sequence.index])
		_next_point()
		return
	_stuck_time += delta
	if guard.global_position.distance_to(_stuck_reference) >= guard.profile.stuck_min_progress_m:
		_stuck_time = 0.0
		_stuck_reference = guard.global_position
	elif _stuck_time >= guard.profile.stuck_timeout_s:
		Log.warn(&"ai", "Guard '%s' is stuck on the way to patrol point %d; skipping it" % [guard.guard_id, _sequence.index])
		_next_point()


func _tick_waiting(delta: float) -> void:
	var point: PatrolPoint = _points[_sequence.index]
	guard.stop()
	if point.use_look_direction:
		guard.look_towards(point.look_direction)
	_wait_remaining -= delta
	var facing_ok: bool = not point.use_look_direction or guard.is_facing(point.look_direction, FACING_TOLERANCE_DEG)
	if _wait_remaining <= 0.0 and facing_ok:
		_next_point()


func _arrive(point: PatrolPoint) -> void:
	phase = Phase.WAITING
	_wait_remaining = point.wait_time
	guard.stop()


func _next_point() -> void:
	guard.clear_look()
	blackboard.patrol_index = _sequence.advance()
	_start_moving()


func _start_moving() -> void:
	if not guard.navigation_ready():
		phase = Phase.WAIT_FOR_NAVIGATION
		return
	phase = Phase.MOVING
	_stuck_time = 0.0
	_stuck_reference = guard.global_position
	guard.navigate_to(_points[_sequence.index].global_position)
