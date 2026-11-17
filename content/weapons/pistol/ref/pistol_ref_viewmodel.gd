extends Node3D
## First-person pistol built from the reference two-handed rig (a tutorial file, low-poly arms and gun; see
## content/LICENSES.md), exported by tools/blender/ref_viewmodel_export.py. It is a test model: the arms and gun are
## blocky, but the rig (IK arms, finger controls, one-handed-to-two-handed reload) is the reference's own.
## There are two skeletons: Arms_Rig (arms) and Gun_Rig (gun and magazine). The clips Idle, Draw, Fire, Reload and
## Reload_Empty play on both at once from one AnimationPlayer. The model faces glTF's front (+Z); Model is turned
## half a turn so the muzzle points along -Z like the other viewmodels. The origin of this node is the camera.
## Exposes the Muzzle node the Weapon node looks for.

## From the slide bone to the front of the barrel, in the gun skeleton's own space (glTF axes), measured in Idle.
const MUZZLE_FROM_SLIDE := Vector3(0.0, 0.009, 0.122)

var _gun_skeleton: Skeleton3D
var _slide_bone: int = -1
var _muzzle: Node3D


func _ready() -> void:
	var model: Node = $Model
	_gun_skeleton = model.get_node("Gun_Rig/Skeleton3D") as Skeleton3D
	_slide_bone = _gun_skeleton.find_bone(&"slide")
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		mesh.layers = FpsArms.LAYER
		if mesh.name == &"arms":
			mesh.add_to_group(&"first_person_arms")
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	add_child(_muzzle)
	_gun_skeleton.skeleton_updated.connect(_follow_muzzle)
	_follow_muzzle()


## The Muzzle node (a direct child, where Weapon looks for it) rides the slide, so the flash and the shot start
## where the barrel is after the recoil.
func _follow_muzzle() -> void:
	if not is_inside_tree():
		return
	var slide: Vector3 = _gun_skeleton.get_bone_global_pose(_slide_bone).origin
	_muzzle.global_position = _gun_skeleton.global_transform * (slide + MUZZLE_FROM_SLIDE)
