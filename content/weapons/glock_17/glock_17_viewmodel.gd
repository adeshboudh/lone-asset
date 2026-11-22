extends ArmsViewmodel
## First-person Glock 17: the developer's arms and pistol on one rig (Files/MS_Glock_17_Animated.glb, supplied with its
## clips; see content/LICENSES.md). Clips used: Glock_17_Idle, Glock_17_Reload_Tactical, Glock_17_Reload_Empty. The
## shared build (textures by surface, Muzzle node, idle loop) is in ArmsViewmodel.
const MODEL := "res://content/weapons/glock_17/Files/MS_Glock_17_Animated.glb"
const GUN_ALBEDO: Texture2D = preload("res://content/weapons/glock_17/Files/TX_Glock_17_AL.png")
const GUN_NORMAL: Texture2D = preload("res://content/weapons/glock_17/Files/TX_Glock_17_NR.png")
## Front of the slide (glb z 0.129, facing flipped), on the barrel axis.
const MUZZLE := Vector3(0.0, -0.001, -0.135)


func _init() -> void:
	model_path = MODEL
	gun_albedo = GUN_ALBEDO
	gun_normal = GUN_NORMAL
	idle_clip = &"Glock_17_Idle"
	muzzle_position = MUZZLE
