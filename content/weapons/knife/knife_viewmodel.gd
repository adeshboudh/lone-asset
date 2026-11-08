extends Node3D
## First-person combat knife: the "M9 Bayonet knife" model by Michael Karel (CC-BY, see
## content/LICENSES.md) in a gloved right hand. The model is life size.
const DIR := "res://content/weapons/knife/textures/"


func _ready() -> void:
	# tilted so the tip rises a little and points inwards, as a knife is held
	var grip: Node3D = Node3D.new()
	grip.name = "Grip"
	grip.rotation_degrees = Vector3(18.0, 10.0, 0.0)
	add_child(grip)
	var knife: Node3D = (load("res://content/weapons/knife/source/M9.fbx") as PackedScene).instantiate()
	grip.add_child(knife)
	# the blade points along +z in the model; forward is -z
	knife.rotation_degrees.y = 180.0
	var material: StandardMaterial3D = LimbBuilder.pbr(DIR, "m9", 0.6)
	for part: Node in knife.find_children("*", "MeshInstance3D"):
		(part as MeshInstance3D).set_surface_override_material(0, material)
	_add_hand(grip)
	var muzzle: Node3D = Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	muzzle.position = Vector3(0.0, 0.07, -0.22)


## Fist round the handle, wrist and forearm running back and down.
func _add_hand(grip: Node3D) -> void:
	var hand: Node3D = Node3D.new()
	hand.name = "Hand"
	grip.add_child(hand)
	var glove: StandardMaterial3D = LimbBuilder.glove_material()
	var sleeve: StandardMaterial3D = LimbBuilder.sleeve_material()
	# handle runs from the guard (z = -0.047) back to the pommel (z = 0.075)
	LimbBuilder.limb(hand, "Palm", Vector3(0.0, -0.014, 0.060), Vector3(0.0, -0.014, 0.000), 0.019, glove)
	for i: int in 4:
		var z: float = -0.030 + 0.020 * i
		LimbBuilder.limb(hand, "FingerA%d" % i, Vector3(0.0, 0.0, z), Vector3(0.0, 0.020, z), 0.0085, glove)
	LimbBuilder.limb(hand, "Thumb", Vector3(-0.020, -0.006, 0.062), Vector3(-0.016, 0.014, -0.032), 0.0085, glove)
	LimbBuilder.limb(hand, "Wrist", Vector3(0.002, -0.020, 0.075), Vector3(0.014, -0.045, 0.120), 0.022, glove)
	LimbBuilder.limb(hand, "Forearm", Vector3(0.014, -0.045, 0.120), Vector3(0.080, -0.170, 0.400), 0.030, sleeve)
