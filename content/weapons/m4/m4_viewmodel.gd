extends Node3D
## First-person viewmodel: the animated M4 + gloved hands pack (BarcodeGames, CC-BY, see content/LICENSES.md).
## Puts the pack's camera bone at this node's origin, textures the gun, swaps the iron sights for a
## thin red-dot sight and exposes the Muzzle node and animation names the Weapon node looks for.
const TEX := "res://content/weapons/m4/textures/"
## Rail top, sight position and muzzle in the pack camera's frame (metres, camera looks along -z).
const RAIL_TOP_Y: float = -0.043
const SIGHT := Vector3(0.071, 0.0, -0.28)
const MUZZLE := Vector3(0.071, -0.07, -0.74)

var animation_player: AnimationPlayer


func _ready() -> void:
	var m4: Node3D = (load("res://content/weapons/m4/source/M4.fbx") as PackedScene).instantiate()
	add_child(m4)
	animation_player = m4.get_node("AnimationPlayer") as AnimationPlayer
	animation_player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	animation_player.play(&"Idle")
	animation_player.seek(0.0, true)
	var skel: Skeleton3D = m4.get_node("Skeleton3D") as Skeleton3D
	skel.force_update_all_bone_transforms()
	var cam: Node3D = skel.get_node("FPS_Camera/FPS_Camera") as Node3D
	# camera pose relative to this node, not to the world: the wrapper sits under the player's camera
	var cam_xf: Transform3D = global_transform.affine_inverse() * cam.global_transform
	m4.transform = cam_xf.affine_inverse()
	_texture(m4)
	var main: MeshInstance3D = skel.get_node("Main/Main") as MeshInstance3D
	main.mesh = _strip_sights(main.mesh as ArrayMesh, global_transform.affine_inverse() * main.global_transform)
	_add_red_dot(main)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	muzzle.position = MUZZLE


func _pbr(albedo: String, normal: String, metallic: float, rough: float, base: Material) -> StandardMaterial3D:
	var m: StandardMaterial3D = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_texture = load(TEX + albedo) as Texture2D
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = load(TEX + normal) as Texture2D
	m.metallic = metallic
	m.roughness = rough
	return m


func _texture(m4: Node3D) -> void:
	var gun_mat: StandardMaterial3D = null
	for n: Node in m4.find_children("*", "MeshInstance3D"):
		var mi: MeshInstance3D = n as MeshInstance3D
		match mi.name:
			&"Hand_Mesh":
				var skin: Material = mi.mesh.surface_get_material(0)
				var glove: Material = mi.mesh.surface_get_material(1)
				var mesh: ArrayMesh = mi.mesh.duplicate() as ArrayMesh
				mesh.surface_set_material(0, _pbr("Hand_D.jpg", "Hand_N.png", 0.0, 0.7, skin))
				mesh.surface_set_material(1, _pbr("Glove_D.png", "Glove_N.png", 0.0, 0.85, glove))
				mi.mesh = mesh
			&"Bullet5_56x45mm", &"Bullet5_56x45mm2":
				mi.material_override = _pbr("Bullet5.56x45mm_D.png", "Bullet5.56x45mm_N.png", 0.9, 0.35, mi.mesh.surface_get_material(0))
			_:
				if gun_mat == null:
					gun_mat = _pbr("M4_D.png", "M4_N.png", 0.55, 0.5, mi.mesh.surface_get_material(0))
				mi.material_override = gun_mat


## Drops the carry-handle rear sight and the front sight post (everything above the rail line in
## those two zones) so nothing blocks the red-dot window. xf maps mesh vertices into the camera frame.
func _strip_sights(src: ArrayMesh, xf: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surf: int in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(surf)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for t: int in range(0, idx.size(), 3):
			var inside: int = 0
			var front_any: bool = false
			for k: int in 3:
				var p: Vector3 = xf * verts[idx[t + k]]
				var fwd: float = -p.z
				var zone: bool = (fwd > -0.10 and fwd < 0.42) or (fwd > 0.48 and fwd < 0.64)
				if zone and p.y > RAIL_TOP_Y + 0.001:
					inside += 1
				# the slim front sight post: any triangle touching it goes, so no tip is left in the window
				if fwd > 0.46 and fwd < 0.66 and p.y > RAIL_TOP_Y + 0.003:
					front_any = true
			if inside < 3 and not front_any:
				kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
		arrays[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(surf, src.surface_get_material(surf))
	return out


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.position = pos


## Reflex sight (Michael Makivic, CC-BY, see content/LICENSES.md), clear lens, no dot: the HUD crosshair is the aim guide.
## The model is 3.5 cm wide; SIGHT_SCALE enlarges it a little so it reads at ADS.
const SIGHT_SCALE: float = 1.3
const LENS_Z: float = -0.034  # front window plane, unscaled, from the model centre


func _add_red_dot(main: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "RedDot"
	main.add_child(holder)
	# lens plane lands on SIGHT.z, feet on the rail
	holder.global_transform = global_transform * Transform3D(Basis.from_scale(Vector3.ONE * SIGHT_SCALE),
			Vector3(SIGHT.x, RAIL_TOP_Y, SIGHT.z - LENS_Z * SIGHT_SCALE))
	var sight: Node3D = (load("res://content/weapons/m4/sight/source/rds_low.fbx") as PackedScene).instantiate() as Node3D
	holder.add_child(sight)
	var rds: MeshInstance3D = sight.get_node("RedDotSight_mesh") as MeshInstance3D
	var mesh: ArrayMesh = rds.mesh.duplicate() as ArrayMesh
	var tex := "res://content/weapons/m4/sight/textures/rds_low_DefaultMaterial_"
	var body := StandardMaterial3D.new()
	body.albedo_texture = load(tex + "BaseColor.tga.png") as Texture2D
	body.metallic = 1.0
	body.metallic_texture = load(tex + "Metallic.tga.png") as Texture2D
	body.roughness_texture = load(tex + "Roughness.tga.png") as Texture2D
	body.normal_enabled = true
	body.normal_texture = load(tex + "Normal.tga.png") as Texture2D
	mesh.surface_set_material(0, body)
	var lens := StandardMaterial3D.new()
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens.albedo_color = Color(0.5, 0.7, 1.0, 0.07)
	lens.roughness = 0.05
	mesh.surface_set_material(1, lens)
	rds.mesh = mesh
	rds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
