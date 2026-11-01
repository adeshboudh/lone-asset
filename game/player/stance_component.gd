class_name StanceComponent
extends Node
## Stand / crouch (design §4): smooth collider and eye-height changes; standing up is blocked under low ceilings.
## The collider is a cylinder: its flat bottom lands cleanly on step edges, which a capsule's rounded bottom does not.

enum Stance { STAND, CROUCH }

var stance: Stance = Stance.STAND
var is_crouched: bool:
	get:
		return stance == Stance.CROUCH
## Current eye height above the feet, in metres (smoothed).
var eye_height: float = 0.0

## 0 = standing, 1 = crouched.
var _blend: float = 0.0
var _collision: CollisionShape3D
var _shape: CylinderShape3D


func setup(collision: CollisionShape3D, settings: PlayerMovementSettings) -> void:
	_collision = collision
	# Each player owns its shape, since its height changes at runtime.
	_shape = CylinderShape3D.new()
	_shape.radius = settings.body_radius
	_collision.shape = _shape
	_apply(settings)


func physics_update(body: CharacterBody3D, intent: InputIntent, settings: PlayerMovementSettings, delta: float) -> void:
	if intent.crouch_toggled:
		if stance == Stance.STAND:
			stance = Stance.CROUCH
		elif has_headroom(body, settings):
			stance = Stance.STAND

	var target: float = 1.0 if is_crouched else 0.0
	if _blend != target:
		_blend = move_toward(_blend, target, delta / settings.stance_transition_time)
		_apply(settings)


## True if a standing collider fits at the body's position.
func has_headroom(body: CharacterBody3D, settings: PlayerMovementSettings) -> bool:
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = settings.body_radius
	shape.height = settings.stand_height
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# Lifted slightly so the floor itself does not count.
	query.transform = Transform3D(Basis(), body.global_position + Vector3.UP * (settings.stand_height * 0.5 + 0.05))
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _apply(settings: PlayerMovementSettings) -> void:
	var t: float = smoothstep(0.0, 1.0, _blend)
	_shape.height = lerpf(settings.stand_height, settings.crouch_height, t)
	# The body origin is at the feet, so the collider shrinks from the top.
	_collision.position.y = _shape.height * 0.5
	eye_height = lerpf(settings.stand_eye_height, settings.crouch_eye_height, t)
