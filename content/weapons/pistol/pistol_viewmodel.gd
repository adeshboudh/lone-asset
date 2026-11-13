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


## The grip: animations turn the arm and the pistol about this point.
const GRIP: Vector3 = GUN_POSITION + Vector3(0.0, -0.02, 0.066)
const V0 := Vector3.ZERO


func _ready() -> void:
	var skeleton: Skeleton3D = HandsRig.build(self, false, HAND_SCALE, GRIP, ARM_DROP_DEG)
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
	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	pivot.position = GRIP
	add_child(pivot)
	skeleton.get_parent().reparent(pivot, true)
	holder.reparent(pivot, true)
	var muzzle: Node3D = Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	muzzle.position = GUN_POSITION + Vector3(0.0, 0.052, -0.1)
	ClipBuilder.add_player(self, ^"Pivot", GRIP, _clips())


## Hand-keyed clips: Idle, Draw, Fire, Reload and Reload_Empty (lengths match the definition's reload times).
func _clips() -> Dictionary:
	return {
		&"Idle": {"length": 3.0, "loop": true, "keys": [
			[0.0, V0, V0], [1.5, Vector3(0.0, 0.002, 0.0), Vector3(0.4, 0.0, 0.0)], [3.0, V0, V0]]},
		&"Draw": {"length": 0.45, "keys": [
			[0.0, Vector3(0.05, -0.22, 0.06), Vector3(-35.0, 20.0, 10.0)],
			[0.3, Vector3(0.0, 0.01, -0.01), Vector3(4.0, 0.0, 0.0)],
			[0.45, V0, V0]]},
		&"Fire": {"length": 0.14, "keys": [
			[0.0, V0, V0], [0.03, Vector3(0.0, 0.004, 0.035), Vector3(6.0, 0.0, 0.0)], [0.14, V0, V0]]},
		&"Reload": {"length": 1.5, "keys": [
			[0.0, V0, V0],
			[0.25, Vector3(0.03, -0.10, 0.05), Vector3(-25.0, 0.0, 25.0)],
			[0.55, Vector3(0.03, -0.11, 0.05), Vector3(-28.0, 0.0, 28.0)],
			[0.8, Vector3(0.03, -0.09, 0.04), Vector3(-22.0, 0.0, 22.0)],
			[1.15, Vector3(0.01, -0.03, 0.0), Vector3(-6.0, 0.0, 6.0)],
			[1.5, V0, V0]]},
		&"Reload_Empty": {"length": 1.9, "keys": [
			[0.0, V0, V0],
			[0.25, Vector3(0.03, -0.10, 0.05), Vector3(-25.0, 0.0, 25.0)],
			[0.6, Vector3(0.03, -0.11, 0.05), Vector3(-28.0, 0.0, 28.0)],
			[0.95, Vector3(0.03, -0.09, 0.04), Vector3(-22.0, 0.0, 22.0)],
			[1.3, Vector3(0.01, -0.02, 0.0), Vector3(-4.0, 0.0, 4.0)],
			[1.5, Vector3(0.0, 0.0, 0.03), Vector3(3.0, 0.0, 0.0)],
			[1.9, V0, V0]]},
	}
