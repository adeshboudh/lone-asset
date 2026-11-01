class_name LevelLighting
extends Node
## Ambient light level of a level, used wherever no LightVolume applies (design §9.1).
## 0 = pitch black, 1 = fully lit. One per level.

const GROUP: StringName = &"level_lighting"

@export_range(0.0, 1.0) var ambient_light_level: float = 0.6


func _enter_tree() -> void:
	add_to_group(GROUP)
