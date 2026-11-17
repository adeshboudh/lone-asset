extends Node3D
## First-person pistol built from the reference two-handed rig (a tutorial file with low-poly arms; see
## content/LICENSES.md), exported by tools/blender/ref_viewmodel_export.py. The arms are the reference's blocky ones
## and the rig (IK arms, finger controls, two-handed reload) is its own; the gun is the real "9mm Pistol" (TORI106,
## CC-BY) skinned to the gun rig's bones, with its textures put on here by material name.
## There are two skeletons: Arms_Rig (arms) and Gun_Rig (gun and magazine). The clips Idle, Draw, Fire, Reload and
## Reload_Empty play on both at once from one AnimationPlayer. The model faces glTF's front (+Z); Model is turned
## half a turn so the muzzle points along -Z like the other viewmodels. The origin of this node is the camera.
## Exposes the Muzzle node the Weapon node looks for.

## From the slide bone to the front of the barrel, in the gun skeleton's own space (glTF axes), measured on the model.
const MUZZLE_FROM_SLIDE := Vector3(0.0004, -0.0252, 0.1215)
const TEXTURES := "res://content/weapons/pistol/textures/"

## How fast the steadiness follows its target (influence per second), so it never snaps on or off.
const STEADY_RATE := 6.0

var _gun_skeleton: Skeleton3D
var _slide_bone: int = -1
var _muzzle: Node3D
var _player: AnimationPlayer
var _modifiers: Array[IdleSteadyModifier] = []
var _aim: float = 0.0
var _steady_amount: float = 0.0
var _idle_speed: float = 1.0
## How much of the idle sway is held still right now (0 = none, 1 = all).
var steady_influence: float = 0.0


func _ready() -> void:
	var model: Node = $Model
	_gun_skeleton = model.get_node("Gun_Rig/Skeleton3D") as Skeleton3D
	_slide_bone = _gun_skeleton.find_bone(&"slide")
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	_add_steadiness(model)
	var gun_materials: Dictionary = {
		&"pistol_frame": LimbBuilder.pbr(TEXTURES, "pistol_9m1"),
		&"pistol_slide": LimbBuilder.pbr(TEXTURES, "pistol_9m2"),
	}
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		mesh.layers = FpsArms.LAYER
		for surface: int in mesh.mesh.get_surface_count():
			var wanted: Material = gun_materials.get(StringName(mesh.mesh.surface_get_material(surface).resource_name)) as Material
			if wanted != null:
				mesh.set_surface_override_material(surface, wanted)
		if mesh.name == &"arms":
			mesh.add_to_group(&"first_person_arms")
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	add_child(_muzzle)
	_gun_skeleton.skeleton_updated.connect(_follow_muzzle)
	_follow_muzzle()


## Aimed, the idle breathing is damped: each skeleton gets a modifier that holds the idle clip's first frame (the
## pose the sights are set for) by an influence the aim raises.
func _add_steadiness(model: Node) -> void:
	var root: Node = _player.get_node(_player.root_node)
	for node: Node in model.find_children("*", "Skeleton3D", true, false):
		var modifier: IdleSteadyModifier = IdleSteadyModifier.new()
		modifier.capture_first_frame(node as Skeleton3D, _player.get_animation(&"Idle"), str(root.get_path_to(node)))
		modifier.influence = 0.0
		node.add_child(modifier)
		_modifiers.append(modifier)


## Called every frame by Weapon: aim is the visual aim (0 hip, 1 aimed), steady how much sway a full aim removes and
## idle_speed the idle clip's speed at full aim.
func set_ads_steadiness(aim: float, steady: float, idle_speed: float) -> void:
	_aim = aim
	_steady_amount = steady
	_idle_speed = idle_speed


func _process(delta: float) -> void:
	# Only the idle breathing is damped: a shot or a reload must keep all of its motion.
	var playing: StringName = StringName(_player.assigned_animation)
	var idling: bool = playing == &"Idle" or playing == &"Draw"
	var wanted: float = _aim * _steady_amount if idling else 0.0
	steady_influence = move_toward(steady_influence, wanted, STEADY_RATE * delta)
	for modifier: IdleSteadyModifier in _modifiers:
		modifier.influence = steady_influence
	_player.speed_scale = lerpf(1.0, _idle_speed, _aim) if idling else 1.0


## The Muzzle node (a direct child, where Weapon looks for it) rides the slide, so the flash and the shot start
## where the barrel is after the recoil.
func _follow_muzzle() -> void:
	if not is_inside_tree():
		return
	var slide: Vector3 = _gun_skeleton.get_bone_global_pose(_slide_bone).origin
	_muzzle.global_position = _gun_skeleton.global_transform * (slide + MUZZLE_FROM_SLIDE)
