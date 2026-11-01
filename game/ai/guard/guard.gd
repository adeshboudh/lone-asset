class_name Guard
extends CharacterBody3D
## An enemy guard (design §7.1). The root owns movement and navigation; the brain decides what to do.

## A navigation target farther than this (horizontally) from the mesh counts as unreachable.
const OFF_MESH_DISTANCE_M: float = 1.0
## A waypoint closer than this (horizontally) counts as reached.
const WAYPOINT_REACHED_M: float = 0.3

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

var _desired_velocity: Vector3 = Vector3.ZERO
## Zero = face the direction of travel.
var _look_direction: Vector3 = Vector3.ZERO
## The last navigate_to target was not on the navigation mesh.
var _target_off_mesh: bool = false
var _waypoint_index: int = 0
var _path_size: int = -1
var _path_start: Vector3 = Vector3.INF
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _agent: NavigationAgent3D = %NavigationAgent
@onready var _health: HealthComponent = %HealthComponent
@onready var _brain: GuardBrain = %Brain
@onready var _model: Node3D = %Model
@onready var _state_label: Label3D = %StateLabel


func _ready() -> void:
	add_to_group(&"guards")
	floor_max_angle = deg_to_rad(40.0)
	floor_snap_length = profile.step_height + 0.05
	_health.max_health = profile.max_health
	_health.reset()
	_health.died.connect(_on_died)

	_state_label.add_to_group(&"debug_view_nodes")
	_state_label.visible = bool(get_tree().get_meta(&"debug_views_enabled", false))

	_brain.setup(self)
	_brain.blackboard.patrol_route = patrol_route
	_brain.add_state(GuardState.PATROL, GuardPatrolState.new())
	_brain.add_state(GuardState.DEAD, GuardDeadState.new())
	_brain.state_changed.connect(_on_state_changed)
	_brain.start(GuardState.PATROL)


func _physics_process(delta: float) -> void:
	_brain.tick(delta)
	_integrate_movement(delta)
	if _state_label.visible:
		_state_label.text = "%s\n%s" % [guard_id, _brain.current_name]


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
	_state_label.add_to_group(&"debug_view_nodes")
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
