extends ArmsViewmodel
## First-person rifle: the developer's arms and rifle on one rig (m4a1_ms_viewmodel.glb, built by
## tools/blender/ms_viewmodel_export.py; see content/LICENSES.md) with its Idle, Reload and Reload_Empty clips.
## The rifle has no suppressor, muzzle brake or optic of its own yet. The shared build is in ArmsViewmodel.
const MODEL := "res://content/weapons/m4a1_ms/m4a1_ms_viewmodel.glb"
## The rifle's texture atlas (albedo downscaled to 2048 px, normal map unchanged). The GLB carries no textures,
## so the materials are built in ArmsViewmodel.
const GUN_ALBEDO: Texture2D = preload("res://content/weapons/m4a1_ms/textures/m4a1_albedo.png")
const GUN_NORMAL: Texture2D = preload("res://content/weapons/m4a1_ms/textures/m4a1_normal.png")
## Muzzle in the viewmodel's frame (metres, the rifle's bore axis, forward is -z).
const MUZZLE := Vector3(0.0, 0.0, -0.6)


func _init() -> void:
	model_path = MODEL
	gun_albedo = GUN_ALBEDO
	gun_normal = GUN_NORMAL
	idle_clip = &"Idle"
	muzzle_position = MUZZLE
