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
	hands.mesh = with_sleeves(mesh, hands.skin)
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


const SLEEVE_ALBEDO: String = "res://content/characters/agent/agent_body_pol_jaket_a.jpg"
const SLEEVE_NORMAL: String = "res://content/characters/agent/agent_body_pol_jaket_n.jpg"
## Share of a vertex's skin weight on the upper arm and forearm bones above which it is sleeve.
const SLEEVE_WEIGHT: float = 0.5


## Returns the arm mesh with the forearms re-skinned as the agent's camouflage sleeves, so the first-person
## arms match the body (bare skin stays on the hands; the gloves keep their own surface).
## mesh: surface 0 skin, surface 1 glove, as in the pack; skin: the mesh instance's skin.
static func with_sleeves(mesh: ArrayMesh, skin: Skin) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per_vertex: int = bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var sleeve_bind: Dictionary = {}
	for bind: int in skin.get_bind_count():
		var bone_name: String = String(skin.get_bind_name(bind))
		if bone_name.ends_with("Arm") or bone_name.ends_with("ForeArm"):
			sleeve_bind[bind] = true
	var is_sleeve: PackedByteArray = PackedByteArray()
	is_sleeve.resize(bones.size() / per_vertex)
	for vertex: int in is_sleeve.size():
		var weight: float = 0.0
		for slot: int in per_vertex:
			if sleeve_bind.has(bones[vertex * per_vertex + slot]):
				weight += weights[vertex * per_vertex + slot]
		is_sleeve[vertex] = 1 if weight >= SLEEVE_WEIGHT else 0
	var skin_indices: PackedInt32Array = PackedInt32Array()
	var sleeve_indices: PackedInt32Array = PackedInt32Array()
	for tri: int in indices.size() / 3:
		var a: int = indices[tri * 3]
		var b: int = indices[tri * 3 + 1]
		var c: int = indices[tri * 3 + 2]
		var target: PackedInt32Array = sleeve_indices if is_sleeve[a] + is_sleeve[b] + is_sleeve[c] >= 2 else skin_indices
		target.append_array(PackedInt32Array([a, b, c]))
	var out: ArrayMesh = ArrayMesh.new()
	arrays[Mesh.ARRAY_INDEX] = skin_indices
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(0, mesh.surface_get_material(0))
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(1))
	out.surface_set_material(1, mesh.surface_get_material(1))
	arrays[Mesh.ARRAY_INDEX] = sleeve_indices
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(2, sleeve_material())
	return out


static func sleeve_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = load(SLEEVE_ALBEDO) as Texture2D
	m.normal_enabled = true
	m.normal_texture = load(SLEEVE_NORMAL) as Texture2D
	m.roughness = 0.9
	# The arm mesh has its own UVs, so the camouflage is projected instead.
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 4.0
	return m
