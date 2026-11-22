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
## so the materials are built here.
const GUN_ALBEDO: Texture2D = preload("res://content/weapons/m4a1_ms/textures/m4a1_albedo.png")
const GUN_NORMAL: Texture2D = preload("res://content/weapons/m4a1_ms/textures/m4a1_normal.png")
## The arms have two surfaces in the GLB (MT_Arms_Sleeves and MT_Arms_Gloves): camouflage jacket sleeves and leather
## gloves, each with an albedo and a normal map.
const SLEEVE_ALBEDO: Texture2D = preload("res://content/weapons/m4a1_ms/textures/sleeves_albedo.png")
const SLEEVE_NORMAL: Texture2D = preload("res://content/weapons/m4a1_ms/textures/sleeves_normal.png")
const GLOVE_ALBEDO: Texture2D = preload("res://content/weapons/m4a1_ms/textures/gloves_albedo.png")
const GLOVE_NORMAL: Texture2D = preload("res://content/weapons/m4a1_ms/textures/gloves_normal.png")
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
	var sleeve_material := _cloth_material(SLEEVE_ALBEDO, SLEEVE_NORMAL, 1.0)
	var glove_material := _cloth_material(GLOVE_ALBEDO, GLOVE_NORMAL, 0.85)
	for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
		var mesh: GeometryInstance3D = node as GeometryInstance3D
		mesh.layers = VIEWMODEL_LAYER
		var is_arms: bool = mesh.name.begins_with("MS_Arms")
		if is_arms:
			mesh.add_to_group(&"first_person_arms")
		if not is_arms:
			mesh.material_override = gun_material
			continue
		var arms_mesh: MeshInstance3D = mesh as MeshInstance3D
		for surface: int in arms_mesh.mesh.get_surface_count():
			var is_glove: bool = String(arms_mesh.mesh.surface_get_material(surface).resource_name).contains("Gloves")
			arms_mesh.set_surface_override_material(surface, glove_material if is_glove else sleeve_material)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	muzzle.position = MUZZLE


## A matte, non-metallic material with an albedo and a normal map (arms; the bright sky shows any shine).
func _cloth_material(albedo: Texture2D, normal: Texture2D, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = albedo
	material.normal_enabled = true
	material.normal_texture = normal
	material.roughness = roughness
	material.metallic_specular = 0.15
	return material
