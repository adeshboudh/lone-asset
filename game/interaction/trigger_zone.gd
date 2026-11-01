class_name TriggerZone
extends Area3D
## A volume that tells the mission the player arrived (design §11.1).

@export var trigger_id: StringName
@export var once: bool = true

var _fired: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player") or (once and _fired):
		return
	_fired = true
	EventBus.trigger_entered.emit(trigger_id)
