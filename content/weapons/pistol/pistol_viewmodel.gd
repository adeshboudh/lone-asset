extends Node3D
## First-person 9mm pistol: the "9mm Pistol" model by TORI106 (CC-BY, see content/LICENSES.md) in the
## right hand of the M4 pack's gloved arms (see hands_rig.gd). Exposes the Muzzle node the Weapon node
## looks for. The origin of this node is the camera, like the M4's.
const DIR := "res://content/weapons/pistol/textures/"
## The model is 2.4 units long, a 9mm pistol about 0.19 m.
const MODEL_SCALE: float = 0.08
## Where the pistol's centre sits in the camera frame, so the grip lies in the hand.
const GUN_POSITION := Vector3(0.075, -0.165, -0.206)
## The pack's arms are sized for a rifle; smaller ones sit better on a pistol. The arm swings down this
## many degrees about the wrist.
const HAND_SCALE: float = 0.85
const ARM_DROP_DEG: float = 25.0
## Extra turn of the pistol about the grip, degrees (pitch, yaw, roll).
const GUN_TURN := Vector3(0.0, 0.0, 0.0)


func _ready() -> void:
	HandsRig.build(self, false, HAND_SCALE, GUN_POSITION + Vector3(0.0, -0.02, 0.066), ARM_DROP_DEG)
	var holder: Node3D = Node3D.new()
	holder.name = "Gun"
	holder.position = GUN_POSITION
	holder.rotation_degrees = GUN_TURN
	add_child(holder)
	var gun: Node3D = (load("res://content/weapons/pistol/source/9mmPistol.fbx") as PackedScene).instantiate()
	holder.add_child(gun)
	# the model points along -x; the muzzle has to point along -z
	gun.rotation_degrees.y = -90.0
	gun.scale = Vector3.ONE * MODEL_SCALE
	var parts: Array[Node] = gun.find_children("*", "MeshInstance3D")
	# first mesh is the frame (map 9m1), the second one the slide parts (map 9m2)
	var maps: Array[StandardMaterial3D] = [LimbBuilder.pbr(DIR, "pistol_9m1"), LimbBuilder.pbr(DIR, "pistol_9m2")]
	for i: int in parts.size():
		(parts[i] as MeshInstance3D).set_surface_override_material(0, maps[mini(i, 1)])
		(parts[i] as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var muzzle: Node3D = Node3D.new()
	muzzle.name = "Muzzle"
	holder.add_child(muzzle)
	muzzle.position = Vector3(0.0, 0.052, -0.1)
