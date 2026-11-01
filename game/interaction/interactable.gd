class_name Interactable
extends Area3D
## Something the player (or a guard) can use (design §12). Sits on the object as a child Area3D on the
## interactable physics layer. The owner of the object listens to `completed`.

const LAYER: int = 8

signal hold_started(actor: Node)
signal hold_stopped(actor: Node)
signal completed(actor: Node)

@export var definition: InteractionDefinition
## Stable ID the mission refers to (design §11.1).
@export var interactable_id: StringName
@export var enabled: bool = true

## What the HUD shows. Starts as the definition's text; the owner changes it (Open / Close).
var prompt_text: String = ""


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	if prompt_text.is_empty() and definition != null:
		prompt_text = definition.prompt_text
	# The player's ray usually hits the object's solid body first, so point that body back at us.
	for sibling: Node in get_parent().get_children():
		if sibling is CollisionObject3D and sibling != self:
			sibling.set_meta(&"interactable", self)


func can_interact(_actor: Node) -> bool:
	return enabled and definition != null


## Finishes the interaction: noise for the player's actions, then the signals.
func complete(actor: Node) -> void:
	if not can_interact(actor):
		return
	if definition.one_shot:
		enabled = false
	if definition.noise_radius_m > 0.0 and actor != null and actor.is_in_group(&"player"):
		NoiseSystem.emit_noise(definition.noise_type, global_position, definition.noise_radius_m, actor)
	completed.emit(actor)
	EventBus.interaction_completed.emit(interactable_id, actor)
