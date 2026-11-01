class_name NoiseListener
extends Node
## Lets its parent (a Node3D) hear gameplay noise. Guards use it from WP 7; NoiseSensor props use it now.
## Registers by group, so NoiseSystem needs no reference to this class.

signal heard(event: NoiseEvent, distance: float, walls: int)

const GROUP: StringName = &"noise_listeners"

var listener_position: Vector3:
	get:
		var parent: Node3D = get_parent() as Node3D
		return parent.global_position if parent != null else Vector3.ZERO


func _enter_tree() -> void:
	add_to_group(GROUP)


func hear(event: NoiseEvent, distance: float, walls: int) -> void:
	heard.emit(event, distance, walls)
