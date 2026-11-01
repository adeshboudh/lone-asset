class_name Binoculars
extends Node
## The player's binoculars (design §13): B raises them, the wheel switches between 4x and 8x, and holding
## a guard in the centre of the view for 0.5 s tags it. Tags show through walls for 60 s (HUD).

signal tagged(guard: Guard)

const WORLD_MASK: int = 1
const FOV_RATE: float = 12.0

var is_active: bool = false
var zoom_index: int = 0
## Camera field of view to use while raised or lowering.
var zoom: float:
	get:
		return BinocularsRules.ZOOM_LEVELS[zoom_index]
## 0 lowered, 1 fully raised; eases so the view zooms smoothly.
var raise_blend: float = 0.0
## Progress (0–1) of the guard currently being tagged, for the reticle.
var tag_progress: float = 0.0

## Keyed by guard_id, so a guard that is freed leaves nothing dangling.
var _progress: Dictionary[StringName, float] = {}
var _tags: Dictionary[StringName, float] = {}


func physics_update(player: Player, intent: InputIntent, delta: float) -> void:
	if intent.binoculars_toggled:
		is_active = not is_active
		_progress.clear()
	if is_active:
		zoom_index = BinocularsRules.step_zoom(zoom_index, intent.zoom_step)
	raise_blend = move_toward(raise_blend, 1.0 if is_active else 0.0, FOV_RATE * delta)
	_expire_tags(delta)
	tag_progress = 0.0
	if is_active:
		_update_tagging(player, delta)


## Seconds left on a guard's tag, 0 if it is not tagged.
func tag_time_left(guard: Guard) -> float:
	return _tags.get(guard.guard_id, 0.0)


func is_tagged(guard: Guard) -> bool:
	return _tags.has(guard.guard_id)


func tag_count() -> int:
	return _tags.size()


func tag(guard: Guard) -> void:
	var was_tagged: bool = is_tagged(guard)
	_tags[guard.guard_id] = BinocularsRules.TAG_DURATION_S
	if not was_tagged:
		Audio.play_ui(&"objective_complete")
		tagged.emit(guard)


func _update_tagging(player: Player, delta: float) -> void:
	var camera: Camera3D = player.camera
	var forward: Vector3 = -camera.global_basis.z
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var guard: Guard = node as Guard
		if guard.is_dead:
			continue
		var centre: Vector3 = guard.global_position + Vector3.UP * 1.2
		var to_guard: Vector3 = centre - camera.global_position
		var angle: float = rad_to_deg(forward.angle_to(to_guard))
		var centred: bool = BinocularsRules.in_tag_cone(angle, to_guard.length()) and _has_sight(camera, centre)
		var progress: float = BinocularsRules.advance_tag(_progress.get(guard.guard_id, 0.0), delta, centred)
		if progress > 0.0:
			_progress[guard.guard_id] = progress
			tag_progress = maxf(tag_progress, progress)
		else:
			_progress.erase(guard.guard_id)
		if progress >= 1.0:
			_progress.erase(guard.guard_id)
			tag(guard)


func _has_sight(camera: Camera3D, target: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, target, WORLD_MASK)
	return camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _expire_tags(delta: float) -> void:
	for id: StringName in _tags.keys():
		_tags[id] -= delta
		if _tags[id] <= 0.0:
			_tags.erase(id)
	# A guard that died or left the level loses its tag.
	var alive: Array[StringName] = []
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var guard: Guard = node as Guard
		if not guard.is_dead:
			alive.append(guard.guard_id)
	for id: StringName in _tags.keys():
		if not alive.has(id):
			_tags.erase(id)
