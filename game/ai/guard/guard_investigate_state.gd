class_name GuardInvestigateState
extends GuardState
## Something is wrong: turn toward it, walk over, and look around (design §7.4).

enum Phase { TURNING, WALKING, LOOKING }
## A new stimulus further than this from the current target moves the target.
const RETARGET_DISTANCE_M: float = 2.5

var phase: Phase = Phase.TURNING

var _target: Vector3 = Vector3.ZERO
var _timer: float = 0.0
var _scan_elapsed: float = 0.0
var _scan_base: Vector3 = Vector3.FORWARD
var _stuck: StuckDetector = StuckDetector.new()


func enter(_previous: StringName) -> void:
	_target = guard.stimulus_position()
	phase = Phase.TURNING
	_timer = guard.profile.turn_to_stimulus_s
	guard.stop()


func exit() -> void:
	guard.stop()
	guard.clear_look()


func tick(delta: float) -> StringName:
	var profile: GuardProfile = guard.profile
	_follow_new_stimulus()
	match phase:
		Phase.TURNING:
			guard.stop()
			guard.look_towards(_target - guard.global_position)
			_timer -= delta
			if _timer <= 0.0:
				_start_walking()
		Phase.WALKING:
			guard.clear_look()
			if guard.is_at(_target):
				_start_looking()
			else:
				guard.move_along_path(profile.investigate_speed)
				if not guard.is_target_reachable() or _stuck.update(guard.global_position, delta, profile.stuck_min_progress_m, profile.stuck_timeout_s):
					_start_looking()
		Phase.LOOKING:
			guard.stop()
			_scan_elapsed += delta
			guard.look_towards(ScanRules.direction_at(_scan_base, _scan_elapsed, profile.scan_step_s, profile.scan_angle_deg))
			# Keep looking until the guard has calmed down below Suspicious.
			if _scan_elapsed >= profile.investigate_look_s and guard.suspicion.band < SuspicionRules.Band.SUSPICIOUS:
				return GuardState.RETURN_TO_PATROL
	return &""


func debug_text() -> String:
	return Phase.keys()[phase]


func _follow_new_stimulus() -> void:
	if phase == Phase.TURNING:
		_target = guard.stimulus_position()
		return
	var latest: Vector3 = guard.stimulus_position()
	if latest.distance_to(_target) > RETARGET_DISTANCE_M:
		_target = latest
		_start_walking()


func _start_walking() -> void:
	phase = Phase.WALKING
	guard.navigate_to(_target)
	_stuck.reset(guard.global_position)


func _start_looking() -> void:
	phase = Phase.LOOKING
	_scan_elapsed = 0.0
	_scan_base = guard.facing()
	guard.stop()
