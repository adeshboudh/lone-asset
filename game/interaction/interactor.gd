class_name Interactor
extends Node
## Finds what the player is looking at and drives the use / hold interaction (design §12).

const REACH_M: float = 2.5
const WORLD_MASK: int = 1

## The interactable in reach and in view, or null.
var focus: Interactable
## 0–1 while holding the key on a timed interaction.
var hold_progress: float = 0.0

var _player: Player
var _holding: Interactable
## After completing or being interrupted, the key must be released before the next use.
var _armed: bool = true


func setup(player: Player) -> void:
	_player = player
	EventBus.damage_applied.connect(_on_damage_applied)


func physics_update(camera: Camera3D, intent: InputIntent, delta: float) -> void:
	focus = _find_focus(camera)
	if not intent.interact:
		_armed = true
		_cancel_hold()
		return
	if focus == null or not _armed:
		_cancel_hold()
		return
	var duration: float = focus.definition.hold_duration
	if duration <= 0.0:
		if intent.interact_pressed:
			_armed = false
			focus.complete(_player)
		return
	if _holding != focus:
		_cancel_hold()
		_holding = focus
		focus.hold_started.emit(_player)
	hold_progress = InteractionRules.advance_hold(hold_progress, delta, duration)
	if hold_progress >= 1.0:
		var done: Interactable = _holding
		_armed = false
		_cancel_hold()
		done.complete(_player)


func _find_focus(camera: Camera3D) -> Interactable:
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_basis.z * REACH_M
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, WORLD_MASK | Interactable.LAYER, [_player.get_rid()])
	query.collide_with_areas = true
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider: Object = hit["collider"]
	var found: Interactable = collider as Interactable
	if found == null and (collider as Node).has_meta(&"interactable"):
		found = (collider as Node).get_meta(&"interactable") as Interactable
	if found == null or not found.can_interact(_player):
		return null
	return found


func _cancel_hold() -> void:
	if _holding != null:
		_holding.hold_stopped.emit(_player)
	_holding = null
	hold_progress = 0.0


func _on_damage_applied(target: Node, _info: DamageInfo, _killed: bool) -> void:
	if target != _player or _holding == null:
		return
	if _holding.definition.interrupt_on_damage:
		_armed = false
		_cancel_hold()
