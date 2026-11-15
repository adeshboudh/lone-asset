class_name FpsArmsSettings
extends Resource
## Tuning for the first-person arms (game/player/fps_arms.gd). Edited in data/player/fps_arms.tres.

## The arms model and its scale (it is authored in centimetres).
@export var model: PackedScene
@export var model_scale: float = 0.01
## The weapon rig's hands are larger than this model's; the hands are scaled about the wrist by this much so the
## fingers meet the grips the rig was animated for.
@export var hand_scale: float = 1.15
