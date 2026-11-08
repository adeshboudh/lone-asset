extends Node3D
## First-person 9mm pistol: the "9mm Pistol" model by TORI106 (CC-BY, see content/LICENSES.md) in two
## gloved hands. Exposes the Muzzle node the Weapon node looks for.
const DIR := "res://content/weapons/pistol/textures/"
## The model is 2.4 units long, a 9mm pistol about 0.19 m.
const MODEL_SCALE: float = 0.08


func _ready() -> void:
	var gun: Node3D = (load("res://content/weapons/pistol/source/9mmPistol.fbx") as PackedScene).instantiate()
	add_child(gun)
	# the model points along -x; the muzzle has to point along -z
	gun.rotation_degrees.y = -90.0
	gun.scale = Vector3.ONE * MODEL_SCALE
	var parts: Array[Node] = gun.find_children("*", "MeshInstance3D")
	# first mesh is the frame (map 9m1), the second one the slide parts (map 9m2)
	var maps: Array[StandardMaterial3D] = [LimbBuilder.pbr(DIR, "pistol_9m1"), LimbBuilder.pbr(DIR, "pistol_9m2")]
	for i: int in parts.size():
		(parts[i] as MeshInstance3D).set_surface_override_material(0, maps[mini(i, 1)])
	_add_hands()
	var muzzle: Node3D = Node3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	muzzle.position = Vector3(0.0, 0.052, -0.1)


## Right hand round the grip, left hand wrapped over it from the other side; forearms run back and down.
func _add_hands() -> void:
	var hands: Node3D = Node3D.new()
	hands.name = "Hands"
	add_child(hands)
	var glove: StandardMaterial3D = LimbBuilder.glove_material()
	var sleeve: StandardMaterial3D = LimbBuilder.sleeve_material()
	# right hand: palm on the right of the grip, fingers round the front strap, thumb forward on the left
	LimbBuilder.limb(hands, "RPalm", Vector3(0.027, 0.018, 0.074), Vector3(0.028, -0.026, 0.082), 0.019, glove)
	for i: int in 3:
		var y: float = 0.006 - 0.014 * i
		LimbBuilder.limb(hands, "RFingerA%d" % i, Vector3(0.027, y, 0.066), Vector3(0.010, y, 0.046), 0.0075, glove)
		LimbBuilder.limb(hands, "RFingerB%d" % i, Vector3(0.010, y, 0.046), Vector3(-0.014, y, 0.056), 0.0068, glove)
	LimbBuilder.limb(hands, "RThumb", Vector3(0.018, 0.026, 0.086), Vector3(-0.020, 0.020, 0.040), 0.0085, glove)
	LimbBuilder.limb(hands, "RWrist", Vector3(0.030, 0.014, 0.090), Vector3(0.050, 0.0, 0.130), 0.021, glove)
	LimbBuilder.limb(hands, "RForearm", Vector3(0.050, 0.0, 0.130), Vector3(0.110, -0.240, 0.330), 0.030, sleeve)
	# left hand: palm on the left of the grip, fingers over the right hand's, thumb forward beside the slide
	LimbBuilder.limb(hands, "LPalm", Vector3(-0.026, -0.024, 0.072), Vector3(-0.026, -0.050, 0.078), 0.018, glove)
	for i: int in 2:
		var y: float = -0.034 - 0.015 * i
		LimbBuilder.limb(hands, "LFingerA%d" % i, Vector3(-0.026, y, 0.062), Vector3(-0.008, y, 0.040), 0.0075, glove)
		LimbBuilder.limb(hands, "LFingerB%d" % i, Vector3(-0.008, y, 0.040), Vector3(0.018, y, 0.052), 0.0068, glove)
	LimbBuilder.limb(hands, "LThumb", Vector3(-0.026, -0.012, 0.074), Vector3(-0.024, -0.002, 0.030), 0.0085, glove)
	LimbBuilder.limb(hands, "LWrist", Vector3(-0.030, -0.040, 0.088), Vector3(-0.056, -0.075, 0.130), 0.021, glove)
	LimbBuilder.limb(hands, "LForearm", Vector3(-0.056, -0.075, 0.130), Vector3(-0.110, -0.250, 0.330), 0.030, sleeve)
