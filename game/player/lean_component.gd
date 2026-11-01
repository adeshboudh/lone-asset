class_name LeanComponent
extends Node
## Leaning around corners (design §4.2): sideways head offset plus roll. Not while sprinting;
## a wall beside the head limits how far the player can lean.

## Clearance kept between the camera and a wall.
const HEAD_CLEARANCE: float = 0.2

## -1 = full left, 1 = full right (smoothed).
var amount: float = 0.0


func physics_update(body: CharacterBody3D, intent: InputIntent, settings: PlayerMovementSettings,
		is_sprinting: bool, head_position: Vector3, delta: float) -> void:
	var target: float = 0.0 if is_sprinting else float(intent.lean)
	if target != 0.0:
		target *= _free_fraction(body, head_position, body.global_basis.x * target, settings)
	amount = move_toward(amount, target, settings.lean_speed * delta)


func apply(pivot: Node3D, settings: PlayerMovementSettings) -> void:
	pivot.position.x = amount * settings.lean_offset
	pivot.rotation.z = -amount * deg_to_rad(settings.lean_angle_deg)


## Fraction (0–1) of the full lean offset that is free of walls on that side.
func _free_fraction(body: CharacterBody3D, head_position: Vector3, side: Vector3, settings: PlayerMovementSettings) -> float:
	var reach: float = settings.lean_offset + HEAD_CLEARANCE
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		head_position, head_position + side * reach, body.collision_mask, [body.get_rid()])
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	var distance: float = head_position.distance_to(hit["position"])
	return clampf((distance - HEAD_CLEARANCE) / settings.lean_offset, 0.0, 1.0)
