extends Node3D
## First-person 9mm pistol with its own two-handed arms. One rig (content/weapons/pistol/rig/pistol_rig.blend, built by
## tools/blender/pistol_rig.py) holds the arms ("fps arms" by DJMaesen, CC-BY) and the pistol ("9mm Pistol" by TORI106,
## CC-BY, see content/LICENSES.md), and its clips move both, so the M4 pack's arms are not used here.
## The model faces glTF's front (+Z); Model is turned half a turn so the muzzle points along -Z like the other
## viewmodels. The origin of this node is the camera. Exposes the Muzzle node the Weapon node looks for.
const ARMS_MODEL := "res://content/characters/fps_arms/fps_arms.glb"
const TEXTURES := "res://content/weapons/pistol/textures/"

var _skeleton: Skeleton3D
var _muzzle: Node3D
var _muzzle_bone: int = -1


func _ready() -> void:
	var model: Node = $Model
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	_apply_materials(model)
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	add_child(_muzzle)
	_muzzle_bone = _skeleton.find_bone(&"gun_muzzle")
	_skeleton.skeleton_updated.connect(_follow_muzzle)
	_follow_muzzle()


## The Muzzle node (a direct child, where Weapon looks for it) rides the muzzle bone, so the flash and the shot start
## where the barrel is after the recoil.
func _follow_muzzle() -> void:
	_muzzle.global_position = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_muzzle_bone)).origin


## The GLB carries plain materials named for what they cover; the textures go on here.
func _apply_materials(model: Node) -> void:
	var by_name: Dictionary = {
		&"arms": _arms_material(),
		&"pistol_frame": LimbBuilder.pbr(TEXTURES, "pistol_9m1"),
		&"pistol_slide": LimbBuilder.pbr(TEXTURES, "pistol_9m2"),
	}
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		mesh.layers = FpsArms.LAYER
		for surface: int in mesh.mesh.get_surface_count():
			var wanted: Material = by_name.get(StringName(mesh.mesh.surface_get_material(surface).resource_name)) as Material
			if wanted != null:
				mesh.set_surface_override_material(surface, wanted)
			if wanted == by_name[&"arms"]:
				mesh.add_to_group(&"first_person_arms")


## The arms' own material, as the fps arms model imports it.
func _arms_material() -> Material:
	var scene: Node = (load(ARMS_MODEL) as PackedScene).instantiate()
	var source: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material: Material = source.mesh.surface_get_material(0)
	scene.free()
	return material
