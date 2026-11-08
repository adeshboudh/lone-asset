extends Node3D
## First-person combat knife: the "M9 Bayonet knife" model by Michael Karel (CC-BY, see
## content/LICENSES.md) in the right fist of the M4 pack's gloved arms (see hands_rig.gd). The model
## is life size. The origin of this node is the camera, like the M4's.
const DIR := "res://content/weapons/knife/textures/"
## Middle of the fist in the camera frame (the same place as the pistol grip).
const FIST := Vector3(0.075, -0.185, -0.14)
## Degrees the blade points above straight ahead.
const BLADE_PITCH_DEG: float = 40.0
const HAND_SCALE: float = 0.85
const ARM_DROP_DEG: float = 25.0
## Centre of the handle in the model, along the blade axis.
const HANDLE_CENTRE_Z: float = -0.014


func _ready() -> void:
	HandsRig.build(self, false, HAND_SCALE, FIST, ARM_DROP_DEG)
	var knife: Node3D = (load("res://content/weapons/knife/source/M9.fbx") as PackedScene).instantiate()
	add_child(knife)
	# the model's tip points along +z; turn it up and forward
	knife.rotation_degrees.x = -(180.0 - BLADE_PITCH_DEG)
	var tip: Vector3 = knife.basis * Vector3.BACK
	knife.position = FIST - knife.basis * Vector3(0.0, 0.0, HANDLE_CENTRE_Z)
	var material: StandardMaterial3D = LimbBuilder.pbr(DIR, "m9", 0.6)
	for part: Node in knife.find_children("*", "MeshInstance3D"):
		(part as MeshInstance3D).set_surface_override_material(0, material)
		(part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var muzzle: Node3D = Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	muzzle.position = knife.position + tip * 0.2
