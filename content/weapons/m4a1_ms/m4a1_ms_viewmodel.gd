extends Node3D
## First-person rifle: the developer's arms and rifle on one rig (m4a1_ms_viewmodel.glb, built by
## tools/blender/ms_viewmodel_export.py; see content/LICENSES.md) with its Idle, Reload and Reload_Empty clips.
## The rig's own arms are drawn, so no FpsArms are added (the rig has no "RightHand" bone). The rifle has no
## suppressor, muzzle brake or optic of its own yet. Exposes the Muzzle node and animation names the Weapon needs.
const MODEL := "res://content/weapons/m4a1_ms/m4a1_ms_viewmodel.glb"
## Layer the viewmodel is drawn on (the scope camera of the old rifle left it out of its picture).
const VIEWMODEL_LAYER: int = 1 << 18
## The model faces +Z after import; the view looks along -Z.
const FACING := Basis(Vector3.UP, PI)
## The rifle's texture atlas (albedo downscaled to 2048 px, normal map unchanged). The GLB carries no textures,
## so the materials are built here. The arms are not in this atlas and keep a plain colour.
const GUN_ALBEDO: Texture2D = preload("res://content/weapons/m4a1_ms/textures/m4a1_albedo.png")
const GUN_NORMAL: Texture2D = preload("res://content/weapons/m4a1_ms/textures/m4a1_normal.png")
const ARMS_COLOR := Color(0.34, 0.36, 0.32)
## Muzzle in the viewmodel's frame (metres, the rifle's bore axis, forward is -z).
const MUZZLE := Vector3(0.0, 0.0, -0.6)

var animation_player: AnimationPlayer


func _ready() -> void:
	var model: Node3D = (load(MODEL) as PackedScene).instantiate() as Node3D
	model.transform = Transform3D(FACING, Vector3.ZERO)
	add_child(model)
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation_player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	animation_player.play(&"Idle")
	var gun_material := StandardMaterial3D.new()
	gun_material.albedo_texture = GUN_ALBEDO
	gun_material.normal_enabled = true
	gun_material.normal_texture = GUN_NORMAL
	gun_material.metallic = 0.5
	gun_material.roughness = 0.6
	var arms_material := StandardMaterial3D.new()
	arms_material.albedo_color = ARMS_COLOR
	arms_material.roughness = 0.8
	for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
		var mesh: GeometryInstance3D = node as GeometryInstance3D
		mesh.layers = VIEWMODEL_LAYER
		var is_arms: bool = mesh.name.begins_with("MS_Arms")
		if is_arms:
			mesh.add_to_group(&"first_person_arms")
		mesh.material_override = arms_material if is_arms else gun_material
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	muzzle.position = MUZZLE
