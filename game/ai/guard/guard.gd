class_name Guard
extends CharacterBody3D
## An enemy guard (design §7.1). The root owns movement and navigation; the brain decides what to do.

## A navigation target farther than this (horizontally) from the mesh counts as unreachable.
const OFF_MESH_DISTANCE_M: float = 1.0
## A waypoint closer than this (horizontally) counts as reached.
const WAYPOINT_REACHED_M: float = 0.3

## Distance between footstep sounds.
const STRIDE_M: float = 1.8

@export var guard_id: StringName = &""
@export var profile: GuardProfile
@export var patrol_route: PatrolRoute

var brain: GuardBrain:
	get:
		return _brain
var health: HealthComponent:
	get:
		return _health
var is_dead: bool:
	get:
		return _brain.current_name == GuardState.DEAD
var suspicion: SuspicionModel
## Seconds this guard has been active (stops when paused or dead). Blackboard times use this clock.
var time: float = 0.0
var weapon: GuardWeapon:
	get:
		return _weapon
## Source of randomness for search points, bursts and repositioning. Tests seed it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _desired_velocity: Vector3 = Vector3.ZERO
## Zero = face the direction of travel.
var _look_direction: Vector3 = Vector3.ZERO
## The last navigate_to target was not on the navigation mesh.
var _target_off_mesh: bool = false
var _waypoint_index: int = 0
var _path_size: int = -1
var _path_start: Vector3 = Vector3.INF
var _step_distance: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _agent: NavigationAgent3D = %NavigationAgent
@onready var _health: HealthComponent = %HealthComponent
@onready var _brain: GuardBrain = %Brain
@onready var _model: Node3D = %Model
@onready var _state_label: Label3D = %StateLabel
@onready var _perception: PerceptionComponent = %PerceptionComponent
@onready var _ears: NoiseListener = %NoiseListener
@onready var _weapon: GuardWeapon = %GuardWeapon


func _ready() -> void:
	add_to_group(&"guards")
	floor_max_angle = deg_to_rad(40.0)
	floor_snap_length = profile.step_height + 0.05
	_health.max_health = profile.max_health
	_health.reset()
	_health.died.connect(_on_died)
	_health.damaged.connect(_on_damaged)

	suspicion = SuspicionModel.new(profile)
	suspicion.band_changed.connect(_on_band_changed)
	_ears.heard.connect(_on_noise_heard)

	_state_label.add_to_group(&"debug_view_nodes")
	_state_label.visible = bool(get_tree().get_meta(&"debug_views_enabled", false))

	_brain.setup(self)
	_brain.blackboard.patrol_route = patrol_route
	rng.randomize()
	_brain.add_state(GuardState.PATROL, GuardPatrolState.new())
	_brain.add_state(GuardState.INVESTIGATE, GuardInvestigateState.new())
	_brain.add_state(GuardState.SEARCH, GuardSearchState.new())
	_brain.add_state(GuardState.COMBAT, GuardCombatState.new())
	_brain.add_state(GuardState.RETURN_TO_PATROL, GuardReturnState.new())
	_brain.add_state(GuardState.DEAD, GuardDeadState.new())
	_brain.state_changed.connect(_on_state_changed)
	_brain.start(GuardState.PATROL)


func _physics_process(delta: float) -> void:
	if not is_dead:
		time += delta
		suspicion.update(delta)
		_escalate()
	_brain.tick(delta)
	_integrate_movement(delta)
	_play_footsteps(delta)
	if _state_label.visible:
		_state_label.text = "%s\n%s %s\n%d  %s" % [guard_id, _brain.current_name, _brain.current_state.debug_text(),
			roundi(suspicion.value), SuspicionRules.Band.keys()[suspicion.band]]


func save_state() -> Dictionary:
	return {
		"guard_id": String(guard_id),
		"alive": not is_dead,
		"position": SaveRules.vector_to_array(global_position),
		"yaw": snappedf(rotation.y, 0.001),
		"suspicion_floor": suspicion.floor_value,
	}


## Loading a checkpoint: a guard that was killed is killed again; a living one goes back to where it
## was, calm, but remembers being on edge (the same suspicion floor as when saved).
func load_state(data: Dictionary) -> void:
	global_position = SaveRules.array_to_vector(data.get("position"))
	rotation.y = float(data.get("yaw", 0.0))
	velocity = Vector3.ZERO
	if not bool(data.get("alive", true)):
		var info: DamageInfo = DamageInfo.new()
		info.type = &"restore"
		info.amount = _health.max_health
		info.hit_position = global_position
		_health.apply_damage(info)
		return
	var floor_level: float = float(data.get("suspicion_floor", 0.0))
	if floor_level > 0.0:
		suspicion.raise_floor(floor_level, -1.0)


## One footstep sound per stride while walking, so a guard can be heard (and found) behind a wall.
func _play_footsteps(delta: float) -> void:
	if is_dead or not is_on_floor():
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed < 0.5:
		_step_distance = 0.0
		return
	_step_distance += speed * delta
	if _step_distance >= STRIDE_M:
		_step_distance = 0.0
		Audio.play_3d(&"footstep_concrete", global_position, &"Footsteps", -4.0, self)


# --- Alertness ---------------------------------------------------------------------------------------

## True while the guard has recently seen the player or been hurt by them.
func has_contact() -> bool:
	return time - _brain.blackboard.last_contact_time <= profile.target_lost_s


func navigation_map() -> RID:
	return _agent.get_navigation_map()


## Suspicion pushes the guard into more alert states (design §7.2). Calming down is up to each state.
func _escalate() -> void:
	var next: StringName = GuardAlertRules.target_state(_brain.current_name, suspicion.band, has_contact())
	if next != &"":
		_brain.transition_to(next)


## A walkable spot a few metres away from which `target_point` can be seen, nearest first; INF if none.
func find_position_with_sight_of(target_point: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var map: RID = navigation_map()
	var best: Vector3 = Vector3.INF
	var best_distance: float = INF
	for i: int in profile.reposition_samples:
		var angle: float = rng.randf() * TAU
		var distance: float = rng.randf_range(profile.reposition_min_m, profile.reposition_max_m)
		var desired: Vector3 = global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		var spot: Vector3 = NavigationServer3D.map_get_closest_point(map, desired)
		if Vector2(spot.x - desired.x, spot.z - desired.z).length() > SearchPlanner.MAX_SNAP_DISTANCE_M:
			continue
		# Eyes are measured from the floor, not from the (floating) navigation mesh.
		var eye: Vector3 = Vector3(spot.x, global_position.y + profile.eye_height_m, spot.z)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, target_point, PerceptionRules.LOS_MASK)
		if not space.intersect_ray(query).is_empty():
			continue
		var travel: float = Vector2(spot.x - global_position.x, spot.z - global_position.z).length()
		if travel < best_distance:
			best_distance = travel
			best = spot
	return best


# --- Senses ------------------------------------------------------------------------------------------

## Where the eyes are.
func eye_position() -> Vector3:
	return global_position + Vector3.UP * profile.eye_height_m


## The direction the guard faces, on the ground plane.
func facing() -> Vector3:
	return -global_basis.z


## The last thing that raised suspicion, for looking at it: a noise position or where the player was seen.
func stimulus_position() -> Vector3:
	if _brain.blackboard.alerted_by == &"noise":
		return _brain.blackboard.investigate_position
	return _brain.blackboard.last_known_position


func has_stimulus() -> bool:
	return _brain.blackboard.alerted_by != &""


## Called by the PerceptionComponent after a check in which the player was at least partly visible.
func on_player_seen(player: Player, visibility: float, distance: float, cone: PerceptionRules.Cone, sighting_s: float) -> void:
	var motion: PerceptionRules.Motion = PerceptionRules.motion_of(player.horizontal_speed, player.is_sprinting)
	suspicion.add_sight(visibility, distance, player.exposure.exposure, player.is_crouched, motion, cone,
		_brain.current_name, sighting_s)
	var blackboard: GuardBlackboard = _brain.blackboard
	blackboard.target = player
	blackboard.last_known_position = player.global_position
	blackboard.last_known_time = time
	blackboard.last_sight_time = time
	blackboard.last_contact_time = time
	blackboard.confidence = visibility
	blackboard.alerted_by = &"sight"


func _on_noise_heard(event: NoiseEvent, _distance: float, _walls: int) -> void:
	if is_dead or event.source == self:
		return
	suspicion.add_noise(event.type)
	_brain.blackboard.investigate_position = event.position
	_brain.blackboard.alerted_by = &"noise"
	# While hunting, the player's gunfire shows where they are even without seeing them.
	var hunting: bool = _brain.current_name == GuardState.COMBAT or _brain.current_name == GuardState.SEARCH
	var gunfire: bool = event.type == NoiseEvent.SHOT or event.type == NoiseEvent.SHOT_SUPPRESSED
	if hunting and gunfire and event.source is Player:
		_brain.blackboard.last_known_position = event.position
		_brain.blackboard.last_known_time = time


func _on_damaged(info: DamageInfo, _amount: float) -> void:
	suspicion.on_damage()
	var blackboard: GuardBlackboard = _brain.blackboard
	blackboard.alerted_by = &"damage"
	var attacker: Node3D = info.source as Node3D
	if attacker != null:
		blackboard.target = attacker
		blackboard.last_known_position = attacker.global_position
		blackboard.last_known_time = time
		blackboard.last_contact_time = time
		blackboard.confidence = 1.0


func _on_band_changed(old_band: SuspicionRules.Band, new_band: SuspicionRules.Band) -> void:
	EventBus.guard_alert_band_changed.emit(self, old_band, new_band)


# --- Movement API used by states -------------------------------------------------------------------

## True once the navigation map has been synchronised, so paths can be requested.
func navigation_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


## Targets are snapped onto the navigation mesh, which floats above the floor. A target more than
## OFF_MESH_DISTANCE_M from the mesh is unreachable.
func navigate_to(position: Vector3) -> void:
	var snapped: Vector3 = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), position)
	var offset: Vector3 = snapped - position
	offset.y = 0.0
	_target_off_mesh = offset.length() > OFF_MESH_DISTANCE_M
	_agent.target_position = snapped
	_waypoint_index = 0
	_path_size = -1


## Walk along the current path at `speed`. Call every tick while travelling.
func move_along_path(speed: float) -> void:
	var direction: Vector3 = _next_waypoint() - global_position
	direction.y = 0.0
	_desired_velocity = direction.normalized() * speed if direction.length() > 0.05 else Vector3.ZERO


## False when no path reaches the target. Only valid after move_along_path has been called this tick.
func is_target_reachable() -> bool:
	return not _target_off_mesh and _agent.is_target_reachable()


func stop() -> void:
	_desired_velocity = Vector3.ZERO


## True when within the profile's arrive distance of `position`, ignoring height.
func is_at(position: Vector3) -> bool:
	var offset: Vector3 = position - global_position
	offset.y = 0.0
	return offset.length() <= profile.arrive_distance


## Turn to face a direction (ignoring height) instead of the direction of travel.
func look_towards(direction: Vector3) -> void:
	_look_direction = Vector3(direction.x, 0.0, direction.z).normalized()


func clear_look() -> void:
	_look_direction = Vector3.ZERO


func is_facing(direction: Vector3, tolerance_deg: float) -> bool:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.001:
		return true
	return absf(rad_to_deg(angle_difference(rotation.y, _yaw_of(flat)))) <= tolerance_deg


## Called by the Dead state.
func on_death() -> void:
	stop()
	clear_look()
	velocity = Vector3.ZERO
	# Dead guards no longer block the player or stop bullets; they stay in the level.
	collision_layer = 0
	collision_mask = 0
	_perception.on_guard_died()
	var tween: Tween = create_tween()
	tween.tween_property(_model, "rotation:x", -PI * 0.5, 0.4).set_ease(Tween.EASE_IN)


# --- Internals ---------------------------------------------------------------------------------------

## The next path waypoint, in order. Waypoints are consumed once reached on the ground plane and never
## revisited, so overshooting one does not make the guard turn back. (The navigation mesh floats above
## the floor, so the agent's own 3D reached-test would never pass its first waypoint.)
func _next_waypoint() -> Vector3:
	_agent.get_next_path_position()  # keeps the agent's path up to date
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	if path.is_empty():
		return global_position
	if path.size() != _path_size or path[0] != _path_start:
		_waypoint_index = 0
		_path_size = path.size()
		_path_start = path[0]
	while _waypoint_index < path.size() - 1:
		var flat: Vector3 = path[_waypoint_index] - global_position
		flat.y = 0.0
		if flat.length() > WAYPOINT_REACHED_M:
			break
		_waypoint_index += 1
	return path[_waypoint_index]


func _integrate_movement(delta: float) -> void:
	if is_dead:
		return
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(_desired_velocity, profile.acceleration * delta)
	var vertical: float = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	velocity = horizontal + Vector3.UP * vertical
	if is_on_floor() and StepUp.try_step(self, horizontal * delta, profile.step_height):
		pass
	else:
		move_and_slide()
	_turn(delta)


func _turn(delta: float) -> void:
	var face: Vector3 = _look_direction
	if face == Vector3.ZERO:
		var travel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		if travel.length() > 0.2:
			face = travel
	if face == Vector3.ZERO:
		return
	var step: float = deg_to_rad(profile.turn_speed_deg) * delta
	rotation.y += clampf(angle_difference(rotation.y, _yaw_of(face)), -step, step)


## Yaw that makes the guard look along `direction` (forward is -Z).
func _yaw_of(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _on_died(_info: DamageInfo) -> void:
	_brain.transition_to(GuardState.DEAD)


func _on_state_changed(old_state: StringName, new_state: StringName) -> void:
	EventBus.guard_state_changed.emit(self, old_state, new_state)
