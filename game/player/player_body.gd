class_name PlayerBody
extends Node3D
## The player's visible body: the agent model standing under the camera. The first-person camera does
## not render the head, helmet or hands, but they still cast shadows, so the player's shadow is a
## whole person. The body is a child of the player, so it turns with the player. It has no collision.
## Walking and crouching are posed in code (no authored animations): legs by two-bone IK on a
## stepping foot path, the pelvis drops and the spine leans when crouched, and the arms reach the
## weapon's hold points.

## Render layer used by parts that only shadows and other cameras see (layer 20).
const HIDDEN_LAYER: int = 1 << 19

@export var model: PackedScene
## Model height 1.87 m scaled to the 1.8 m stand collider.
@export var model_scale: float = 0.96
## Body is set back from the camera so the neck and chest are not around the eye (m).
@export var setback_m: float = 0.1
@export_group("Walk")
@export var foot_lift_m: float = 0.12
## Longest half-step of a foot, in metres.
@export var max_foot_amplitude_m: float = 0.32
@export var pelvis_bob_m: float = 0.04
@export var air_tuck_m: float = 0.25
## Extra pelvis drop on a hard landing, in metres.
@export var landing_dip_max_m: float = 0.2
@export var sprint_lean_deg: float = 10.0
@export_group("Lean")
## Spine tilt at full lean, in degrees, and the sideways reach of the hands in metres.
@export var lean_body_deg: float = 25.0
@export var lean_offset_m: float = 0.3
@export_group("Crouch")
## How far the pelvis drops when fully crouched, in metres.
@export var crouch_drop_m: float = 0.5
## Forward lean of the spine when fully crouched, in degrees.
@export var crouch_lean_deg: float = 20.0

## Bones in the agent model: shoulder, elbow, wrist / hip, knee, ankle. The model's +x side is the
## player's left; the model faces +z.
const LEFT_ARM: PackedStringArray = ["Bone.013", "Bone.014", "Bone.015"]
const RIGHT_ARM: PackedStringArray = ["Bone.036", "Bone.037", "Bone.038"]
const LEFT_LEG: PackedStringArray = ["Bone.007", "Bone.008", "Bone.009"]
const RIGHT_LEG: PackedStringArray = ["Bone.010", "Bone.011", "Bone.012"]
const ROOT_BONE: StringName = &"Bone"
const SPINE_BONE: StringName = &"Bone.002"

var _stand_eye_height: float = 1.65
var _crouch_eye_height: float = 1.0
## A copy of each weapon's model that only the body shows: shadows and other cameras see the gun in the
## body's hands, the first-person camera does not draw it (the real viewmodel does that).
class BodyGun extends RefCounted:
	var node: Node3D
	var skeleton: Skeleton3D
	var animation: AnimationPlayer
	var right_hand: int = -1
	var left_hand: int = -1

var _guns: Dictionary = {}
var _gun_root: Node3D
var _visual: Node3D
var _skeleton: Skeleton3D
var _phase: float = 0.0
## 0 = standing still, 1 = walking (smoothed).
var _gait: float = 0.0
var _sprint: float = 0.0
var _air: float = 0.0
var _was_airborne: bool = false
var _fall_speed: float = 0.0
var _landing: float = 0.0


func setup(camera: Camera3D, stand_eye_height: float, crouch_eye_height: float) -> void:
	_stand_eye_height = stand_eye_height
	_crouch_eye_height = crouch_eye_height
	camera.cull_mask &= ~HIDDEN_LAYER
	_gun_root = Node3D.new()
	_gun_root.name = "BodyGuns"
	camera.add_child(_gun_root)
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


## Makes a body-only copy of each weapon's model. Call once the weapons exist.
func attach_guns(weapons: Array[Weapon]) -> void:
	for weapon: Weapon in weapons:
		if weapon.definition.viewmodel_scene == null or _guns.has(weapon):
			continue
		var gun: BodyGun = BodyGun.new()
		gun.node = weapon.definition.viewmodel_scene.instantiate()
		_gun_root.add_child(gun.node)
		for mesh: Node in gun.node.find_children("*", "GeometryInstance3D", true, false):
			var instance: GeometryInstance3D = mesh as GeometryInstance3D
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			instance.layers = HIDDEN_LAYER
			# The first-person arms are replaced by the body's own.
			if instance.name == &"Hand_Mesh" or instance.is_in_group(&"first_person_arms"):
				instance.visible = false
		var skeletons: Array[Node] = gun.node.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			gun.skeleton = skeletons[0] as Skeleton3D
			gun.right_hand = gun.skeleton.find_bone("RightHand")
			gun.left_hand = gun.skeleton.find_bone("LeftHand")
			# The pistol's own two-handed rig names its wrists differently.
			if gun.right_hand < 0:
				gun.right_hand = gun.skeleton.find_bone("R_wrist_025")
			if gun.left_hand < 0:
				gun.left_hand = gun.skeleton.find_bone("L_wrist_03")
			# The reference pistol rig (a test model) names them hand_R and hand_L.
			if gun.right_hand < 0:
				gun.right_hand = gun.skeleton.find_bone("hand_R")
			if gun.left_hand < 0:
				gun.left_hand = gun.skeleton.find_bone("hand_L")
			# The rifle's own rig (arms and gun in one armature) names them Wrist_R and Wrist_L.
			if gun.right_hand < 0:
				gun.right_hand = gun.skeleton.find_bone("Wrist_R")
			if gun.left_hand < 0:
				gun.left_hand = gun.skeleton.find_bone("Wrist_L")
		gun.animation = gun.node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		gun.node.visible = false
		_guns[weapon] = gun


func update(state: BodyPoseState, weapon: Weapon, delta: float) -> void:
	if _skeleton == null:
		return
	var crouch: float = smoothstep(0.0, 1.0, GaitRules.crouch_amount(state.eye_height, _stand_eye_height, _crouch_eye_height))
	var walking: bool = state.grounded and state.ground_speed > 0.3
	_gait = move_toward(_gait, 1.0 if walking else 0.0, delta * 6.0)
	_sprint = move_toward(_sprint, 1.0 if state.sprinting and walking else 0.0, delta * 5.0)
	_air = move_toward(_air, 0.0 if state.grounded else 1.0, delta * 8.0)
	if walking:
		_phase = GaitRules.advance_phase(_phase, state.ground_speed, state.stride_m, delta)
	# Landing: remember how fast the fall was, dip when the feet touch, recover.
	if not state.grounded:
		_fall_speed = maxf(_fall_speed, -state.vertical_speed)
	elif _was_airborne:
		_landing = GaitRules.landing_dip_m(_fall_speed, landing_dip_max_m)
		_fall_speed = 0.0
	_was_airborne = not state.grounded
	_landing = move_toward(_landing, 0.0, delta * 0.8)
	var bob: float = -GaitRules.pelvis_offset_m(_phase, pelvis_bob_m) * _gait * (1.0 - crouch * 0.5)
	var pelvis_drop: float = crouch * crouch_drop_m + bob + _landing
	_pose_torso(pelvis_drop, crouch, state.lean, _sprint)
	var amplitude: float = GaitRules.foot_amplitude_m(state.stride_m, max_foot_amplitude_m) * _gait
	var lift: float = foot_lift_m * _gait * (1.0 + _sprint * 0.6)
	# In the air the knees tuck: both feet come up.
	var tuck: Vector2 = Vector2(0.05, air_tuck_m) * _air
	_pose_leg(LEFT_LEG, GaitRules.foot_offset(_phase, amplitude, lift) + tuck)
	_pose_leg(RIGHT_LEG, GaitRules.foot_offset(_phase + PI, amplitude, lift) + tuck)
	var eye_drop: float = _stand_eye_height - state.eye_height
	var lean_shift: float = state.lean * lean_offset_m
	var definition: WeaponDefinition = weapon.definition if weapon != null else null
	for held: Weapon in _guns:
		(_guns[held] as BodyGun).node.visible = held == weapon and held.visible
	var gun: BodyGun = _sync_gun(weapon)
	if state.binoculars_blend > 0.01 or definition == null:
		var blend: float = smoothstep(0.0, 1.0, state.binoculars_blend)
		var right: Vector3 = _hand_from_gun(gun, true, definition, state, eye_drop, lean_shift)
		var left: Vector3 = _hand_from_gun(gun, false, definition, state, eye_drop, lean_shift)
		_pose_arm(RIGHT_ARM, right.lerp(PlayerBodyRules.binocular_hand(1.0, state.eye_height) + Vector3(lean_shift, 0.0, 0.0), blend), true)
		_pose_arm(LEFT_ARM, left.lerp(PlayerBodyRules.binocular_hand(-1.0, state.eye_height) + Vector3(lean_shift, 0.0, 0.0), blend), true)
	else:
		_pose_arm(RIGHT_ARM, _hand_from_gun(gun, true, definition, state, eye_drop, lean_shift), true)
		_pose_arm(LEFT_ARM, _hand_from_gun(gun, false, definition, state, eye_drop, lean_shift), definition.hold_uses_left_hand)


## Moves the weapon's body copy to where the real viewmodel is and plays the same animation frame.
func _sync_gun(weapon: Weapon) -> BodyGun:
	if weapon == null or not _guns.has(weapon) or weapon.viewmodel == null:
		return null
	var gun: BodyGun = _guns[weapon]
	gun.node.global_transform = weapon.viewmodel.global_transform
	if gun.node.has_method(&"show_suppressor"):
		gun.node.call(&"show_suppressor", weapon.definition.suppressed)
	var source: AnimationPlayer = weapon.animation_player
	if gun.animation != null and source != null and source.current_animation != &"":
		gun.animation.assigned_animation = source.current_animation
		gun.animation.seek(source.current_animation_position, true)
	return gun


## Hand target in body space: the wrist of the gun's own arm rig when it has one (so the hands follow
## the fire and reload animations), else the weapon's fixed hold point.
func _hand_from_gun(gun: BodyGun, right: bool, definition: WeaponDefinition, state: BodyPoseState, eye_drop: float, lean_shift: float) -> Vector3:
	var bone: int = -1
	if gun != null and gun.skeleton != null:
		bone = gun.right_hand if right else gun.left_hand
	if bone >= 0:
		var wrist: Vector3 = gun.skeleton.global_transform * gun.skeleton.get_bone_global_pose(bone).origin
		return global_transform.affine_inverse() * wrist
	if definition == null:
		return Vector3(0.0, state.eye_height - 0.3, -0.4)
	return _hand(definition, right, state, eye_drop, lean_shift)


func _hand(weapon: WeaponDefinition, right: bool, state: BodyPoseState, eye_drop: float, lean_shift: float) -> Vector3:
	return PlayerBodyRules.hand_target(weapon.hold_right_hand if right else weapon.hold_left_hand, weapon.hold_ads_offset,
			smoothstep(0.0, 1.0, state.aim_blend), weapon.hold_sprint_offset, _sprint, eye_drop, lean_shift)


## Lowers the pelvis (metres), leans the spine forward when crouched or sprinting and sideways when peeking.
func _pose_torso(drop_m: float, crouch: float, lean: float, sprint: float) -> void:
	var root: int = _skeleton.find_bone(ROOT_BONE)
	var spine: int = _skeleton.find_bone(SPINE_BONE)
	if root < 0 or spine < 0:
		return
	_skeleton.set_bone_pose_position(root, _skeleton.get_bone_rest(root).origin + Vector3(0.0, -drop_m / model_scale, 0.0))
	var forward: Basis = Basis(Vector3.RIGHT, deg_to_rad(crouch_lean_deg * crouch + sprint_lean_deg * sprint))
	# The model's -x side is the player's right; rotating about +z tips the head toward -x.
	var sideways: Basis = Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(lean_body_deg) * lean)
	_set_global_basis(spine, sideways * forward * _skeleton.get_bone_global_rest(spine).basis)


## Bends one leg so the ankle reaches its standing spot plus the step offset (x forward, y up).
func _pose_leg(bones: PackedStringArray, step: Vector2) -> void:
	var ankle: int = _skeleton.find_bone(bones[2])
	if ankle < 0:
		return
	var target: Vector3 = _skeleton.get_bone_global_rest(ankle).origin + Vector3(0.0, step.y, step.x)
	_reach(bones, target, Vector3(0.0, 0.0, 1.0))
	# The foot stays flat on the floor whatever the shin does.
	_set_global_basis(ankle, _skeleton.get_bone_global_rest(ankle).basis)


## Bends one arm so its hand reaches the point (body space), or lets it hang in the rest pose.
func _pose_arm(bones: PackedStringArray, hand_target: Vector3, reach: bool) -> void:
	var shoulder: int = _skeleton.find_bone(bones[0])
	var elbow: int = _skeleton.find_bone(bones[1])
	if shoulder < 0 or elbow < 0:
		return
	if not reach:
		_skeleton.set_bone_pose_rotation(shoulder, _skeleton.get_bone_rest(shoulder).basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_rotation(elbow, _skeleton.get_bone_rest(elbow).basis.get_rotation_quaternion())
		return
	var rest_shoulder_x: float = _skeleton.get_bone_global_rest(shoulder).origin.x
	var target: Vector3 = _skeleton.global_transform.affine_inverse() * (global_transform * hand_target)
	# Elbows point down and out.
	_reach(bones, target, Vector3(signf(rest_shoulder_x) * 0.6, -1.0, 0.3))


## Two-bone reach: turns the upper and lower bone so the chain ends at the target (skeleton space).
func _reach(bones: PackedStringArray, target: Vector3, pole: Vector3) -> void:
	var upper: int = _skeleton.find_bone(bones[0])
	var lower: int = _skeleton.find_bone(bones[1])
	var end: int = _skeleton.find_bone(bones[2])
	if upper < 0 or lower < 0 or end < 0:
		return
	var rest_upper: Vector3 = _skeleton.get_bone_global_rest(upper).origin
	var rest_lower: Vector3 = _skeleton.get_bone_global_rest(lower).origin
	var rest_end: Vector3 = _skeleton.get_bone_global_rest(end).origin
	var upper_length: float = rest_upper.distance_to(rest_lower)
	var lower_length: float = rest_lower.distance_to(rest_end)
	# The top of the chain may have moved with the torso.
	var start: Vector3 = _skeleton.get_bone_global_pose(upper).origin
	var new_lower: Vector3 = ArmIkRules.elbow(start, target, upper_length, lower_length, pole)
	var new_end: Vector3 = new_lower + (target - new_lower).normalized() * lower_length
	_turn_bone(upper, rest_lower - rest_upper, new_lower - start)
	_turn_bone(lower, rest_end - rest_lower, new_end - new_lower)


## Turns a bone so the direction it pointed at in the rest pose now points along new_direction.
func _turn_bone(bone: int, rest_direction: Vector3, new_direction: Vector3) -> void:
	_set_global_basis(bone, Basis(ArmIkRules.aim(rest_direction, new_direction)) * _skeleton.get_bone_global_rest(bone).basis)


func _set_global_basis(bone: int, global_basis_new: Basis) -> void:
	var parent: int = _skeleton.get_bone_parent(bone)
	var parent_basis: Basis = _skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	_skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * global_basis_new).get_rotation_quaternion())
