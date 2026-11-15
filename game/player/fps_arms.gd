class_name FpsArms
extends Node3D
## The player's arms in first person: a dedicated arms model ("fps arms" by DJMaesen, CC-BY, see
## content/LICENSES.md) posed every frame from the weapon's own arm rig (the M4 pack's skeleton, which the
## weapon's animations move), so every clip of every weapon on that rig drives the arms, fingers included.
## Added under the rig's Skeleton3D by Weapon._build_viewmodel. Maths in FpsArmsRules.

## Same layer as the weapon viewmodel, so the scope's picture camera leaves the arms out too.
const LAYER: int = 1 << 18
## A rig arm scaled below this is collapsed on purpose (one-handed weapons hide the left arm).
const COLLAPSED_SCALE: float = 0.01
const KIND_OTHER: int = 0
const KIND_UPPER_ARM: int = 1
const KIND_THUMB: int = 2

## One arm of the new model and the rig bones that drive it.
class ArmSide extends RefCounted:
	var prefix: String
	var shoulder: int = -1
	var wrist: int = -1
	var rig_shoulder: int = -1
	var rig_wrist: int = -1
	## Driven bones, parent first: [new bone, rig bone, new child, rig child, kind]; the children give each bone's
	## direction.
	var bones: Array[PackedInt32Array] = []
	## Frame of each driven bone at rest (new model's skeleton space), same order as bones.
	var frames_rest: Array[Basis] = []
	## Knuckles and wrist used for the hand's axes: [wrist, index1, middle1, pinky1] on each rig.
	var hand: PackedInt32Array
	var rig_hand: PackedInt32Array

var skeleton: Skeleton3D
var _rig: Skeleton3D
var _settings: FpsArmsSettings
var _sides: Array[ArmSide] = []
## The new skeleton's space in the rig skeleton's space.
var _to_rig: Transform3D


## Puts the arms on the first skeleton in the viewmodel that has a "RightHand" bone. Returns null when there is
## none (a weapon without an arm rig).
static func attach(viewmodel: Node3D, settings: FpsArmsSettings) -> FpsArms:
	if settings == null or settings.model == null:
		return null
	for node: Node in viewmodel.find_children("*", "Skeleton3D", true, false):
		var rig: Skeleton3D = node as Skeleton3D
		if rig.find_bone("RightHand") >= 0:
			var arms := FpsArms.new()
			arms.name = "FpsArms"
			rig.add_child(arms)
			arms._setup(rig, settings)
			return arms
	return null


func _setup(rig: Skeleton3D, settings: FpsArmsSettings) -> void:
	_rig = rig
	_settings = settings
	# After the weapon's AnimationPlayer has posed the rig this frame.
	process_priority = 1000
	var model: Node3D = settings.model.instantiate() as Node3D
	model.scale = Vector3.ONE * settings.model_scale
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
		var mesh: GeometryInstance3D = node as GeometryInstance3D
		mesh.layers = LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_to_rig = _rig.global_transform.affine_inverse() * skeleton.global_transform
	for prefix: String in ["L_", "R_"]:
		var side: ArmSide = _build_side(prefix)
		if side != null:
			_sides.append(side)
	pose_from_rig()


func _process(_delta: float) -> void:
	pose_from_rig()


func _bone(prefix: String, joint: String) -> int:
	for bone: int in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone).begins_with(prefix + joint + "_"):
			return bone
	return -1


func _build_side(prefix: String) -> ArmSide:
	var side := ArmSide.new()
	side.prefix = prefix
	var rig_prefix: String = "Left" if prefix == "L_" else "Right"
	side.shoulder = _bone(prefix, "arm")
	side.wrist = _bone(prefix, "wrist")
	side.rig_shoulder = _rig.find_bone(rig_prefix + "Arm")
	side.rig_wrist = _rig.find_bone(rig_prefix + "Hand")
	side.hand = PackedInt32Array([side.wrist, _bone(prefix, "point1"), _bone(prefix, "middle1"), _bone(prefix, "pink1")])
	side.rig_hand = PackedInt32Array([side.rig_wrist, _rig.find_bone(rig_prefix + "HandIndex1"),
			_rig.find_bone(rig_prefix + "HandMiddle1"), _rig.find_bone(rig_prefix + "HandPinky1")])
	if side.hand.has(-1) or side.rig_hand.has(-1) or side.rig_shoulder < 0:
		return null
	for bone: int in skeleton.get_bone_count():
		var bone_name: String = skeleton.get_bone_name(bone)
		if not bone_name.begins_with(prefix):
			continue
		var rig_bone: int = _rig.find_bone(FpsArmsRules.pack_bone(bone_name))
		if rig_bone < 0:
			continue
		var child: int
		var rig_child: int
		if bone == side.wrist:
			child = side.hand[2]
			rig_child = side.rig_hand[2]
		else:
			child = skeleton.get_bone_children(bone)[0]
			rig_child = _rig.get_bone_children(rig_bone)[0]
		side.bones.append(PackedInt32Array([bone, rig_bone, child, rig_child, _kind(bone_name)]))
	var rest: Callable = func(bone: int) -> Vector3: return skeleton.get_bone_global_rest(bone).origin
	for entry: PackedInt32Array in side.bones:
		side.frames_rest.append(_frame(entry[4], entry[0], entry[2], side.hand, rest))
	return side


## The frame of a bone from joint positions: x toward its child, z a sideways axis that means the same on both
## rigs (the elbow's bend for the upper arm, the palm's normal for the thumb, which lies along the knuckles, and
## the hand's index-to-little-finger line for the rest). hand: [wrist, index1, middle1, pinky1].
func _frame(kind: int, bone: int, child: int, hand: PackedInt32Array, at: Callable) -> Basis:
	var origin: Vector3 = at.call(bone)
	var direction: Vector3 = (at.call(child) as Vector3) - origin
	var across: Vector3 = (at.call(hand[3]) as Vector3) - (at.call(hand[1]) as Vector3)
	var sideways: Vector3 = across
	if kind == KIND_UPPER_ARM:
		sideways = (at.call(hand[0]) as Vector3) - (at.call(child) as Vector3)
	elif kind == KIND_THUMB:
		sideways = across.cross((at.call(hand[2]) as Vector3) - (at.call(hand[0]) as Vector3))
	return FpsArmsRules.bone_frame(direction, sideways)


static func _kind(bone_name: String) -> int:
	if bone_name.contains("_arm_"):
		return KIND_UPPER_ARM
	if bone_name.contains("_thumb"):
		return KIND_THUMB
	return KIND_OTHER


func pose_from_rig() -> void:
	if skeleton == null or _rig == null:
		return
	var to_new: Basis = _to_rig.basis.orthonormalized().inverse()
	var rig_at: Callable = func(bone: int) -> Vector3: return _rig.get_bone_global_pose(bone).origin
	for side: ArmSide in _sides:
		var collapsed: bool = _rig.get_bone_pose_scale(side.rig_shoulder).x < COLLAPSED_SCALE
		skeleton.set_bone_pose_scale(side.shoulder, Vector3.ONE * (0.001 if collapsed else 1.0))
		if collapsed:
			continue
		skeleton.set_bone_pose_scale(side.wrist, Vector3.ONE * _settings.hand_scale)
		for i: int in side.bones.size():
			var entry: PackedInt32Array = side.bones[i]
			var rig_frame: Basis = _frame(entry[4], entry[1], entry[3], side.rig_hand, rig_at)
			var wanted: Basis = FpsArmsRules.retarget(to_new * rig_frame, side.frames_rest[i],
					skeleton.get_bone_global_rest(entry[0]).basis.orthonormalized())
			_set_global_basis(entry[0], wanted)
		# The wrist lands on the rig's wrist; the shoulder moves to make it so.
		var wrist_target: Vector3 = _to_rig.affine_inverse() * _rig.get_bone_global_pose(side.rig_wrist).origin
		var miss: Vector3 = wrist_target - skeleton.get_bone_global_pose(side.wrist).origin
		var parent: int = skeleton.get_bone_parent(side.shoulder)
		var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
		skeleton.set_bone_pose_position(side.shoulder, skeleton.get_bone_pose_position(side.shoulder) + parent_basis.inverse() * miss)


func _set_global_basis(bone: int, wanted: Basis) -> void:
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * wanted).get_rotation_quaternion())
