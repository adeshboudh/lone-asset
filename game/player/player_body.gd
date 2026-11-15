class_name PlayerBody
extends Node3D
## The player's visible body: the agent model standing under the camera. The first-person camera does
## not render the head, helmet or hands, but they still cast shadows, so the player's shadow is a
## whole person. The body is a child of the player, so it turns with the player and lowers when
## crouching. It has no collision.

## Render layer used by parts that only shadows and other cameras see (layer 20).
const HIDDEN_LAYER: int = 1 << 19

@export var model: PackedScene
## Model height 1.87 m scaled to the 1.8 m stand collider.
@export var model_scale: float = 0.96
## Body is set back from the camera so the neck and chest are not around the eye (m).
@export var setback_m: float = 0.1
## How far the model squashes on crouch, 0 = not at all (placeholder until crouch animation).
@export_range(0.0, 1.0) var crouch_squash: float = 0.6

var _stand_eye_height: float = 1.65
var _visual: Node3D


func setup(camera: Camera3D, stand_eye_height: float) -> void:
	_stand_eye_height = stand_eye_height
	camera.cull_mask &= ~HIDDEN_LAYER
	if model == null:
		return
	_visual = model.instantiate()
	# Models face +Z; the player faces -Z.
	_visual.rotation.y = PI
	_visual.scale = Vector3.ONE * model_scale
	_visual.position = Vector3(0.0, 0.0, setback_m)
	add_child(_visual)
	for mesh: Node in _visual.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = mesh as MeshInstance3D
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if PlayerBodyRules.hidden_from_camera(instance.name):
			instance.layers = HIDDEN_LAYER


func update(eye_height: float) -> void:
	if _visual != null:
		_visual.scale = Vector3(model_scale, model_scale * PlayerBodyRules.height_scale(eye_height, _stand_eye_height, crouch_squash), model_scale)
