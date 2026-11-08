class_name LimbBuilder
extends RefCounted
## Material helper for the static first-person models (pistol, knife).


## A PBR material from the maps of one asset: albedo, roughness and metallic (grey images, red channel) and normal.
static func pbr(dir: String, prefix: String, metallic_scale: float = 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = load(dir + prefix + "_albedo.jpg") as Texture2D
	m.roughness_texture = load(dir + prefix + "_roughness.jpg") as Texture2D
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic = metallic_scale
	m.metallic_texture = load(dir + prefix + "_metallic.jpg") as Texture2D
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = load(dir + prefix + "_normal.png") as Texture2D
	return m
