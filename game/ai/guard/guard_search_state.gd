class_name GuardSearchState
extends GuardState
## Looking for an enemy that was heard or lost: visit random walkable points around where it was last
## known, scanning at each, until nothing has happened for a long time (design §7.4).

enum Phase { MOVING, SCANNING }
## A stimulus this far from the current search centre starts a new search around it.
const RECENTRE_DISTANCE_M: float = 6.0

var phase: Phase = Phase.MOVING

var _center: Vector3 = Vector3.ZERO
var _points: Array[Vector3] = []
var _index: int = 0
var _scan_elapsed: float = 0.0
var _scan_base: Vector3 = Vector3.FORWARD
var _stuck: StuckDetector = StuckDetector.new()


func enter(_previous: StringName) -> void:
	guard.suspicion.raise_floor(guard.profile.search_floor, guard.profile.search_floor_duration_s)
	_plan_around(guard.stimulus_position())


func exit() -> void:
	guard.stop()
	guard.clear_look()


func tick(delta: float) -> StringName:
	var profile: GuardProfile = guard.profile
	if guard.suspicion.seconds_since_stimulus >= profile.search_timeout_s:
		return GuardState.RETURN_TO_PATROL
	if guard.suspicion.seconds_since_stimulus < 1.0 and guard.stimulus_position().distance_to(_center) > RECENTRE_DISTANCE_M:
		_plan_around(guard.stimulus_position())

	match phase:
		Phase.MOVING:
			guard.clear_look()
			if guard.is_at(_points[_index]):
				_start_scanning()
			else:
				guard.move_along_path(profile.search_speed)
				if not guard.is_target_reachable() or _stuck.update(guard.global_position, delta, profile.stuck_min_progress_m, profile.stuck_timeout_s):
					_start_scanning()
		Phase.SCANNING:
			guard.stop()
			_scan_elapsed += delta
			guard.look_towards(ScanRules.direction_at(_scan_base, _scan_elapsed, profile.scan_step_s, profile.scan_angle_deg))
			if _scan_elapsed >= profile.search_scan_s:
				_next_point()
	return &""


func debug_text() -> String:
	return "%s %d/%d" % [Phase.keys()[phase], _index + 1, _points.size()]


## The points the guard is visiting, for tests and the debug view.
func points() -> Array[Vector3]:
	return _points


func _plan_around(center: Vector3) -> void:
	_center = center
	_points = SearchPlanner.plan(guard.navigation_map(), guard.global_position, center, guard.profile, guard.rng)
	_index = 0
	_go_to_current_point()


func _next_point() -> void:
	_index += 1
	if _index >= _points.size():
		# Everything checked and still nothing: look again around the same place.
		_plan_around(_center)
	else:
		_go_to_current_point()


func _go_to_current_point() -> void:
	phase = Phase.MOVING
	guard.navigate_to(_points[_index])
	_stuck.reset(guard.global_position)


func _start_scanning() -> void:
	phase = Phase.SCANNING
	_scan_elapsed = 0.0
	_scan_base = guard.facing()
	guard.stop()
