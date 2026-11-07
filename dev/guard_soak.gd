extends Node
## Developer tool (acceptance row 13): runs the movement course with the player removed and checks that
## every guard keeps patrolling. A run is one full pass over a guard's patrol points, counting only
## points the guard really arrived at; a guard counts as stuck when it arrives at no new point for
## STUCK_AFTER_S seconds of game time.
##   make soak                      (20 runs per guard)
##   make soak RUNS=5
## Runs as fast as the machine allows (fixed time step). Excluded from game exports.

const COURSE: PackedScene = preload("res://game/levels/graybox/movement_course.tscn")
const STUCK_AFTER_S: float = 60.0
const MAX_SIM_S: float = 3600.0
const PHYSICS_TICK_S: float = 1.0 / 60.0

var _runs_wanted: int = 20
var _guards: Array[Guard] = []
var _visited: Dictionary = {}
var _last_point: Dictionary = {}
var _last_progress_s: Dictionary = {}
var _runs_done: Dictionary = {}
var _stuck: Dictionary = {}
var _sim_s: float = 0.0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			_runs_wanted = maxi(int(arg.trim_prefix("--runs=")), 1)
	var course: Node = COURSE.instantiate()
	add_child(course)
	course.get_node("Player").free()
	for node: Node in course.get_node("Guards").get_children():
		var guard: Guard = node as Guard
		# Fast walking and short waits keep a run short; the route and the navigation are unchanged.
		guard.profile = guard.profile.duplicate()
		guard.profile.patrol_speed = 5.0
		for point: PatrolPoint in guard.patrol_route.points():
			point.wait_time = 0.2
		_guards.append(guard)
		_visited[guard.guard_id] = {}
		_last_point[guard.guard_id] = -1
		_last_progress_s[guard.guard_id] = 0.0
		_runs_done[guard.guard_id] = 0
		_stuck[guard.guard_id] = false
	print("Soak: %d guards, %d runs each" % [_guards.size(), _runs_wanted])


func _physics_process(delta: float) -> void:
	_sim_s += delta
	var finished: bool = true
	for guard: Guard in _guards:
		var id: StringName = guard.guard_id
		if _stuck[id] or _runs_done[id] >= _runs_wanted:
			continue
		finished = false
		_track(guard, id)
	if finished or _sim_s > MAX_SIM_S:
		_report()


func _track(guard: Guard, id: StringName) -> void:
	var patrol: GuardPatrolState = guard.brain.current_state as GuardPatrolState
	# Only an arrival counts (the guard stands waiting at the point): the patrol state skips a point it
	# cannot reach, which moves the index on without the guard having walked there.
	if patrol != null and patrol.phase == GuardPatrolState.Phase.WAITING and patrol.point_index != _last_point[id]:
		_last_point[id] = patrol.point_index
		_last_progress_s[id] = _sim_s
		var seen: Dictionary = _visited[id]
		seen[patrol.point_index] = true
		if seen.size() >= guard.patrol_route.points().size():
			seen.clear()
			_runs_done[id] += 1
	if _sim_s - _last_progress_s[id] > STUCK_AFTER_S:
		_stuck[id] = true
		var state_name: StringName = guard.brain.current_name
		print("STUCK: %s after %d runs at %s in state %s" % [id, _runs_done[id], guard.global_position, state_name])


func _report() -> void:
	set_physics_process(false)
	var failed: bool = false
	for guard: Guard in _guards:
		var id: StringName = guard.guard_id
		var ok: bool = not _stuck[id] and _runs_done[id] >= _runs_wanted
		failed = failed or not ok
		print("%s: %d/%d runs, %s" % [id, _runs_done[id], _runs_wanted, "ok" if ok else "FAILED"])
	print("Soak %s after %.0f s of game time" % ["FAILED" if failed else "passed", _sim_s])
	get_tree().quit(1 if failed else 0)
