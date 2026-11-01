class_name GuardCombatState
extends GuardState
## Fighting the player (design §7.4). Three sub-states:
## ENGAGE: has a view of the target, so it stands, faces it and fires bursts, aiming better over time.
## REPOSITION: every few seconds, or when hurt, it moves to another spot with a view of the target.
## CHASE: lost sight, so it runs to where the target was last known.
## The fight ends (and a search starts) when the target has not been seen or felt for target_lost_s.

enum Phase { ENGAGE, REPOSITION, CHASE }
## A sighting counts as a clear view for this long.
const VIEW_GRACE_S: float = 0.4
const REACTION_AFTER_REGAINING_VIEW_S: float = 0.15
## Moving the chase destination only when the last known position shifted this much.
const CHASE_RETARGET_M: float = 1.0

var phase: Phase = Phase.CHASE

var _engaged_s: float = 0.0
var _reaction_s: float = 0.0
var _burst_left: int = 0
var _pause_s: float = 0.0
var _reposition_in: float = 0.0
var _reposition_elapsed: float = 0.0
var _reposition_target: Vector3 = Vector3.ZERO
var _chase_target: Vector3 = Vector3.INF
var _scan_elapsed: float = 0.0
var _scan_base: Vector3 = Vector3.FORWARD
var _hurt: bool = false
var _stuck: StuckDetector = StuckDetector.new()


func enter(_previous: StringName) -> void:
	guard.suspicion.raise_floor(guard.profile.combat_floor, -1.0)
	guard.health.damaged.connect(_on_damaged)
	_reaction_s = guard.profile.reaction_delay_s
	_reposition_in = _next_reposition_delay()
	_hurt = false
	_engaged_s = 0.0
	_burst_left = 0
	_pause_s = 0.0
	_chase_target = Vector3.INF
	phase = Phase.ENGAGE if _has_view() else Phase.CHASE


func exit() -> void:
	if guard.health.damaged.is_connected(_on_damaged):
		guard.health.damaged.disconnect(_on_damaged)
	guard.stop()
	guard.clear_look()


func tick(delta: float) -> StringName:
	var player: Player = blackboard.target as Player
	if player == null or not is_instance_valid(player) or player.health.is_dead:
		return GuardState.RETURN_TO_PATROL
	if guard.time - blackboard.last_contact_time > guard.profile.target_lost_s:
		return GuardState.SEARCH

	match phase:
		Phase.ENGAGE:
			_tick_engage(delta, player)
		Phase.REPOSITION:
			_tick_reposition(delta)
		Phase.CHASE:
			_tick_chase(delta)
	return &""


func debug_text() -> String:
	return "%s  ammo %d" % [Phase.keys()[phase], guard.weapon.logic.magazine]


func _tick_engage(delta: float, player: Player) -> void:
	if not _has_view():
		_enter_chase()
		return
	var profile: GuardProfile = guard.profile
	var chest: Vector3 = player.perception_points()[1]
	var to_target: Vector3 = chest - guard.eye_position()
	guard.stop()
	guard.look_towards(to_target)
	_engaged_s += delta
	_reaction_s -= delta
	_reposition_in -= delta

	var trigger: bool = false
	if _pause_s > 0.0:
		_pause_s -= delta
	elif _reaction_s <= 0.0 and guard.is_facing(to_target, profile.fire_alignment_deg):
		trigger = true
	var shots: int = guard.weapon.update(delta, trigger, chest, AimRules.error_deg(profile, _engaged_s, player.horizontal_speed))
	if trigger:
		if _burst_left <= 0:
			_burst_left = guard.rng.randi_range(profile.burst_min, profile.burst_max)
		_burst_left -= shots
		if _burst_left <= 0:
			_burst_left = 0
			_pause_s = guard.rng.randf_range(profile.burst_pause_min_s, profile.burst_pause_max_s)

	if _reposition_in <= 0.0 or _hurt:
		_hurt = false
		_reposition_in = _next_reposition_delay()
		var spot: Vector3 = guard.find_position_with_sight_of(chest)
		if spot != Vector3.INF:
			_reposition_target = spot
			_reposition_elapsed = 0.0
			phase = Phase.REPOSITION
			guard.navigate_to(spot)
			_stuck.reset(guard.global_position)


func _tick_reposition(delta: float) -> void:
	var profile: GuardProfile = guard.profile
	_reposition_elapsed += delta
	guard.clear_look()
	var done: bool = guard.is_at(_reposition_target) or _reposition_elapsed >= profile.reposition_timeout_s
	if not done:
		guard.move_along_path(profile.run_speed)
		done = not guard.is_target_reachable() or _stuck.update(guard.global_position, delta, profile.stuck_min_progress_m, profile.stuck_timeout_s)
	if done:
		guard.stop()
		_reaction_s = REACTION_AFTER_REGAINING_VIEW_S
		if _has_view():
			phase = Phase.ENGAGE
		else:
			_enter_chase()


func _tick_chase(delta: float) -> void:
	var profile: GuardProfile = guard.profile
	if _has_view():
		phase = Phase.ENGAGE
		_reaction_s = REACTION_AFTER_REGAINING_VIEW_S
		return
	var destination: Vector3 = blackboard.last_known_position
	if _chase_target == Vector3.INF or destination.distance_to(_chase_target) > CHASE_RETARGET_M:
		_chase_target = destination
		guard.navigate_to(destination)
		_stuck.reset(guard.global_position)
		_scan_elapsed = 0.0
	if guard.is_at(_chase_target) or not guard.is_target_reachable():
		# Got there and the target is gone: look around until the fight times out.
		guard.stop()
		_scan_elapsed += delta
		guard.look_towards(ScanRules.direction_at(_scan_base, _scan_elapsed, profile.scan_step_s, profile.scan_angle_deg))
		return
	_scan_base = guard.facing()
	guard.clear_look()
	guard.move_along_path(profile.run_speed)
	if _stuck.update(guard.global_position, delta, profile.stuck_min_progress_m, profile.stuck_timeout_s):
		_chase_target = destination
		guard.stop()


func _enter_chase() -> void:
	phase = Phase.CHASE
	_engaged_s = 0.0
	_burst_left = 0
	_chase_target = Vector3.INF
	_scan_base = guard.facing()


## True while the guard has seen the target within the last moment.
func _has_view() -> bool:
	return guard.time - blackboard.last_sight_time <= VIEW_GRACE_S


func _next_reposition_delay() -> float:
	return guard.rng.randf_range(guard.profile.reposition_interval_min_s, guard.profile.reposition_interval_max_s)


func _on_damaged(_info: DamageInfo, _amount: float) -> void:
	_hurt = true
