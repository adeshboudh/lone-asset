class_name HandsRig
extends RefCounted
## The gloved arms from the M4 pack (BarcodeGames, CC-BY, see content/LICENSES.md) without the rifle,
## for weapons that come without hands. Posed from the pack's idle frame, so the right hand is a
## closed fist on a grip; the left arm can be hidden for one-handed weapons.

const TEX := "res://content/weapons/m4/textures/"


## Adds the arms under parent, in the pack's camera frame (the camera is the origin of parent).
## Returns the skeleton so the caller can pose bones.
## hand_scale shrinks the arms about hold_point (camera frame); arm_drop_deg swings the arm down about
## the wrist so the forearm stays out of the sight picture.
static func build(parent: Node3D, show_left_arm: bool, hand_scale: float = 1.0, hold_point: Vector3 = Vector3.ZERO,
		arm_drop_deg: float = 0.0) -> Skeleton3D:
	var rig: Node3D = (load("res://content/weapons/m4/source/M4.fbx") as PackedScene).instantiate()
	parent.add_child(rig)
	var player: AnimationPlayer = rig.get_node("AnimationPlayer") as AnimationPlayer
	player.play(&"Idle")
	player.seek(0.0, true)
	player.stop(true)  # keep the pose
	var skeleton: Skeleton3D = rig.get_node("Skeleton3D") as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	var camera: Node3D = skeleton.get_node("FPS_Camera/FPS_Camera") as Node3D
	rig.transform = (parent.global_transform.affine_inverse() * camera.global_transform).affine_inverse()
	if arm_drop_deg != 0.0:
		_drop_arm(skeleton, rig, arm_drop_deg)
	if hand_scale != 1.0:
		rig.transform = Transform3D(Basis.from_scale(Vector3.ONE * hand_scale), hold_point * (1.0 - hand_scale)) * rig.transform
	for child: Node in skeleton.get_children():
		if child is BoneAttachment3D:
			(child as Node3D).visible = false  # the rifle's parts
	if not show_left_arm:
		skeleton.set_bone_pose_scale(skeleton.find_bone("LeftArm"), Vector3.ONE * 0.001)
	var hands: MeshInstance3D = skeleton.get_node("Hand_Mesh") as MeshInstance3D
	var mesh: ArrayMesh = hands.mesh.duplicate() as ArrayMesh
	mesh.surface_set_material(0, _pbr("Hand_D.jpg", "Hand_N.png", hands.mesh.surface_get_material(0)))
	mesh.surface_set_material(1, _pbr("Glove_D.png", "Glove_N.png", hands.mesh.surface_get_material(1)))
	hands.mesh = mesh
	hands.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return skeleton


## Turns the upper arm and forearm about the wrist (camera-frame X axis, positive swings the elbow down)
## and puts the hand back where it was.
static func _drop_arm(skeleton: Skeleton3D, rig: Node3D, degrees: float) -> void:
	var hand: int = skeleton.find_bone("RightHand")
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand)
	var axis: Vector3 = (rig.transform.basis.inverse() * Vector3.RIGHT).normalized()
	var turn: Transform3D = Transform3D(Basis(axis, deg_to_rad(degrees)), Vector3.ZERO)
	var pivot: Vector3 = hand_pose.origin
	for bone_name: String in ["RightArm", "RightForeArm"]:
		var bone: int = skeleton.find_bone(bone_name)
		var pose: Transform3D = skeleton.get_bone_global_pose(bone)
		var moved: Transform3D = Transform3D(turn.basis * pose.basis, pivot + turn.basis * (pose.origin - pivot))
		skeleton.set_bone_global_pose(bone, moved)
	skeleton.set_bone_global_pose(hand, hand_pose)


static func _pbr(albedo: String, normal: String, base: Material) -> StandardMaterial3D:
	var m: StandardMaterial3D = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_texture = load(TEX + albedo) as Texture2D
	m.normal_enabled = true
	m.normal_texture = load(TEX + normal) as Texture2D
	m.roughness = 0.8
	return m
