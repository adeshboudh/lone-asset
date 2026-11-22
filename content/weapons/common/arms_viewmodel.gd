class_name ArmsViewmodel
extends Node3D
## Base of the first-person viewmodels built from the developer's arms-and-gun rigs (one GLB per weapon: arms, gun and
## armature with the weapon's clips). A weapon script extends this and sets the fields below in _init(). The rig's own
## arms are drawn, so no FpsArms are added. Exposes the Muzzle node and `animation_player` the Weapon needs.
## Layer the viewmodel is drawn on (a scope camera can leave it out of its picture).
const VIEWMODEL_LAYER: int = 1 << 18
## The models face +Z after import; the view looks along -Z.
const FACING := Basis(Vector3.UP, PI)
## The arms have two surfaces in the GLB (MT_Arms_Sleeves and MT_Arms_Gloves): camouflage jacket sleeves and leather
## gloves, shared by every weapon.
const SLEEVE_ALBEDO: Texture2D = preload("res://content/weapons/common/textures/sleeves_albedo.png")
const SLEEVE_NORMAL: Texture2D = preload("res://content/weapons/common/textures/sleeves_normal.png")
const GLOVE_ALBEDO: Texture2D = preload("res://content/weapons/common/textures/gloves_albedo.png")
const GLOVE_NORMAL: Texture2D = preload("res://content/weapons/common/textures/gloves_normal.png")

## Set by the subclass.
var model_path: String
var gun_albedo: Texture2D
var gun_normal: Texture2D
## Clip held while idle (looped).
var idle_clip: StringName
## Muzzle in the viewmodel's frame (metres, the bore axis, forward is -z).
var muzzle_position: Vector3

var animation_player: AnimationPlayer


func _ready() -> void:
	var model: Node3D = (load(model_path) as PackedScene).instantiate() as Node3D
	model.transform = Transform3D(FACING, Vector3.ZERO)
	add_child(model)
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation_player.get_animation(idle_clip).loop_mode = Animation.LOOP_LINEAR
	animation_player.play(idle_clip)
	var gun_material := StandardMaterial3D.new()
	gun_material.albedo_texture = gun_albedo
	gun_material.normal_enabled = true
	gun_material.normal_texture = gun_normal
	gun_material.metallic = 0.5
	gun_material.roughness = 0.6
	var sleeve_material: StandardMaterial3D = _cloth_material(SLEEVE_ALBEDO, SLEEVE_NORMAL, 1.0)
	var glove_material: StandardMaterial3D = _cloth_material(GLOVE_ALBEDO, GLOVE_NORMAL, 0.85)
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
	muzzle.position = muzzle_position


## A matte, non-metallic material with an albedo and a normal map (arms; the bright sky shows any shine).
func _cloth_material(albedo: Texture2D, normal: Texture2D, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = albedo
	material.normal_enabled = true
	material.normal_texture = normal
	material.roughness = roughness
	material.metallic_specular = 0.15
	return material
