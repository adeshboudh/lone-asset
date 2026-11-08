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


const V0 := Vector3.ZERO


func _ready() -> void:
	var skeleton: Skeleton3D = HandsRig.build(self, false, HAND_SCALE, FIST, ARM_DROP_DEG)
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
	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	pivot.position = FIST
	add_child(pivot)
	skeleton.get_parent().reparent(pivot, true)
	knife.reparent(pivot, true)
	var muzzle: Node3D = Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	muzzle.position = FIST + tip * 0.2
	ClipBuilder.add_player(self, ^"Pivot", FIST, _clips())


## Hand-keyed clips. Fire is the quick slash (fire button): wind up to the right, cut across to the
## left. Fire_Alt is the heavy thrust (aim button). Lengths match melee_swing_s and melee_heavy_swing_s.
func _clips() -> Dictionary:
	return {
		&"Idle": {"length": 3.0, "loop": true, "keys": [
			[0.0, V0, V0], [1.5, Vector3(0.0, 0.002, 0.0), Vector3(0.0, 0.0, 0.8)], [3.0, V0, V0]]},
		&"Draw": {"length": 0.4, "keys": [
			[0.0, Vector3(0.08, -0.25, 0.08), Vector3(-40.0, -25.0, 20.0)],
			[0.28, Vector3(0.0, 0.01, -0.01), Vector3(5.0, 0.0, 0.0)],
			[0.4, V0, V0]]},
		&"Fire": {"length": 0.45, "keys": [
			[0.0, V0, V0],
			[0.12, Vector3(0.09, 0.0, 0.06), Vector3(10.0, -35.0, 15.0)],
			[0.24, Vector3(-0.10, -0.03, -0.14), Vector3(-10.0, 50.0, -25.0)],
			[0.45, V0, V0]]},
		&"Fire_Alt": {"length": 0.8, "keys": [
			[0.0, V0, V0],
			[0.3, Vector3(0.03, -0.02, 0.12), Vector3(15.0, 0.0, 0.0)],
			[0.4, Vector3(-0.02, 0.0, -0.30), Vector3(-10.0, 0.0, 0.0)],
			[0.55, Vector3(-0.02, 0.0, -0.28), Vector3(-8.0, 0.0, 0.0)],
			[0.8, V0, V0]]},
	}
