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
## A weapon's own left-hand hold (a "LeftHandHold" node on the gun, see the rifle viewmodel, if it has one) applies fully
## while the rig's left hand is within HOLD_NEAR_M of where it rests at Idle, and lets go by HOLD_FAR_M.
const HOLD_NEAR_M: float = 0.04
const HOLD_FAR_M: float = 0.12
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
	## Index of the wrist in bones.
	var wrist_entry: int = -1

var skeleton: Skeleton3D
var _rig: Skeleton3D
var _settings: FpsArmsSettings
var _sides: Array[ArmSide] = []
## The new skeleton's space in the rig skeleton's space.
var _to_rig: Transform3D
## The weapon's left-hand hold, if it has one, and the rig's left wrist at Idle in the hold's frame.
var _hold: Node3D
var _hold_rest: Vector3


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
			arms._hold = viewmodel.find_child("LeftHandHold", true, false) as Node3D
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
	if _hold != null:
		_hold_rest = hold_in_rig().affine_inverse() * _rig.get_bone_global_pose(_rig.find_bone("LeftHand")).origin
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
		if entry[0] == side.wrist:
			side.wrist_entry = side.frames_rest.size() - 1
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
		# The wrist lands on the rig's wrist (or the weapon's hold); the shoulder moves to make it so.
		var wrist_target: Vector3 = _to_rig.affine_inverse() * _rig.get_bone_global_pose(side.rig_wrist).origin
		if side.prefix == "L_" and _hold != null:
			wrist_target = _apply_hold(side, to_new, wrist_target)
		var miss: Vector3 = wrist_target - skeleton.get_bone_global_pose(side.wrist).origin
		var parent: int = skeleton.get_bone_parent(side.shoulder)
		var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
		skeleton.set_bone_pose_position(side.shoulder, skeleton.get_bone_pose_position(side.shoulder) + parent_basis.inverse() * miss)


## Turns the left hand toward the weapon's hold and opens the fingers, by how near the rig's hand is to its Idle
## place on the gun. Returns the wrist target (new skeleton's space).
func _apply_hold(side: ArmSide, to_new: Basis, rig_wrist_target: Vector3) -> Vector3:
	var hold_xf: Transform3D = hold_in_rig()
	var weight: float = FpsArmsRules.hold_weight((hold_xf.affine_inverse() * _rig.get_bone_global_pose(side.rig_wrist).origin).distance_to(_hold_rest),
			HOLD_NEAR_M, HOLD_FAR_M)
	if weight <= 0.0:
		return rig_wrist_target
	var wanted: Basis = FpsArmsRules.retarget(to_new * hold_xf.basis.orthonormalized(), side.frames_rest[side.wrist_entry],
			skeleton.get_bone_global_rest(side.wrist).basis.orthonormalized())
	var current: Basis = skeleton.get_bone_global_pose(side.wrist).basis.orthonormalized()
	var target: Basis = current.slerp(wanted, weight)
	# The forearm takes the roll about its own length, so the wrist does not twist like a wrapper.
	var elbow: int = skeleton.get_bone_parent(side.wrist)
	var forearm: Vector3 = skeleton.get_bone_global_pose(side.wrist).origin - skeleton.get_bone_global_pose(elbow).origin
	var roll: Quaternion = FpsArmsRules.twist((target * current.inverse()).get_rotation_quaternion(), forearm)
	_set_global_basis(elbow, Basis(roll) * skeleton.get_bone_global_pose(elbow).basis.orthonormalized())
	_set_global_basis(side.wrist, target)
	var open: float = float(_hold.get_meta(&"finger_open", 0.0)) * weight
	for entry: PackedInt32Array in side.bones:
		if entry[0] == side.wrist or entry[4] == KIND_UPPER_ARM or skeleton.get_bone_name(entry[0]).contains("_elbow_"):
			continue
		var rest: Quaternion = skeleton.get_bone_rest(entry[0]).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(entry[0], skeleton.get_bone_pose_rotation(entry[0]).slerp(rest, open))
	var hold_target: Vector3 = _to_rig.affine_inverse() * hold_xf.origin
	return rig_wrist_target.lerp(hold_target, weight)


## The weapon's left-hand hold in the rig skeleton's space, from the pose of the bone it rides (a BoneAttachment3D
## only moves after the skeleton's deferred update, a frame late).
func hold_in_rig() -> Transform3D:
	var attachment: BoneAttachment3D = _hold.get_parent() as BoneAttachment3D
	if attachment != null and attachment.get_parent() == _rig:
		return _rig.get_bone_global_pose(_rig.find_bone(attachment.bone_name)) * _hold.transform
	return _rig.global_transform.affine_inverse() * _hold.global_transform


func _set_global_basis(bone: int, wanted: Basis) -> void:
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * wanted).get_rotation_quaternion())
