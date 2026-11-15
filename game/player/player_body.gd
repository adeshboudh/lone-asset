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
## Arm bones in the agent model: shoulder, elbow and wrist. The model's +x side is the player's left.
const LEFT_ARM: PackedStringArray = ["Bone.013", "Bone.014", "Bone.015"]
const RIGHT_ARM: PackedStringArray = ["Bone.036", "Bone.037", "Bone.038"]

var _visual: Node3D
var _skeleton: Skeleton3D


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
	var skeletons: Array[Node] = _visual.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
	for mesh: Node in _visual.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = mesh as MeshInstance3D
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if PlayerBodyRules.hidden_from_camera(instance.name):
			instance.layers = HIDDEN_LAYER


func update(eye_height: float, weapon: WeaponDefinition) -> void:
	if _visual == null:
		return
	_visual.scale = Vector3(model_scale, model_scale * PlayerBodyRules.height_scale(eye_height, _stand_eye_height, crouch_squash), model_scale)
	if _skeleton != null and weapon != null:
		_pose_arm(RIGHT_ARM, weapon.hold_right_hand, true)
		_pose_arm(LEFT_ARM, weapon.hold_left_hand, weapon.hold_uses_left_hand)


## Bends one arm so its hand reaches the point (body space), or lets it hang in the rest pose.
func _pose_arm(bones: PackedStringArray, hand_target: Vector3, reach: bool) -> void:
	var shoulder: int = _skeleton.find_bone(bones[0])
	var elbow: int = _skeleton.find_bone(bones[1])
	var wrist: int = _skeleton.find_bone(bones[2])
	if shoulder < 0 or elbow < 0 or wrist < 0:
		return
	_skeleton.set_bone_pose_rotation(shoulder, _skeleton.get_bone_rest(shoulder).basis.get_rotation_quaternion())
	_skeleton.set_bone_pose_rotation(elbow, _skeleton.get_bone_rest(elbow).basis.get_rotation_quaternion())
	if not reach:
		return
	var rest_shoulder: Vector3 = _skeleton.get_bone_global_rest(shoulder).origin
	var rest_elbow: Vector3 = _skeleton.get_bone_global_rest(elbow).origin
	var rest_wrist: Vector3 = _skeleton.get_bone_global_rest(wrist).origin
	var target: Vector3 = _skeleton.global_transform.affine_inverse() * (global_transform * hand_target)
	# Elbows point down and out.
	var pole: Vector3 = Vector3(signf(rest_shoulder.x) * 0.6, -1.0, 0.3)
	var new_elbow: Vector3 = ArmIkRules.elbow(rest_shoulder, target, rest_shoulder.distance_to(rest_elbow), rest_elbow.distance_to(rest_wrist), pole)
	var new_wrist: Vector3 = new_elbow + (target - new_elbow).normalized() * rest_elbow.distance_to(rest_wrist)
	_turn_bone(shoulder, rest_elbow - rest_shoulder, new_elbow - rest_shoulder)
	_turn_bone(elbow, rest_wrist - rest_elbow, new_wrist - new_elbow)


## Turns a bone so the direction it pointed at in the rest pose now points along new_direction.
func _turn_bone(bone: int, rest_direction: Vector3, new_direction: Vector3) -> void:
	var rest_global: Basis = _skeleton.get_bone_global_rest(bone).basis
	var global_basis_new: Basis = Basis(ArmIkRules.aim(rest_direction, new_direction)) * rest_global
	var parent: int = _skeleton.get_bone_parent(bone)
	var parent_basis: Basis = _skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	_skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * global_basis_new).get_rotation_quaternion())
