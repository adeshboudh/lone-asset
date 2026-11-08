class_name LimbBuilder
extends RefCounted
## Builds the simple gloved hands for first-person models that come without any.


static func glove_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.075, 0.08, 0.07)
	m.roughness = 0.85
	return m


static func sleeve_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.13, 0.11)
	m.roughness = 0.95
	return m


## A capsule from a to b under parent.
static func limb(parent: Node3D, limb_name: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = limb_name
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = a.distance_to(b) + radius * 2.0
	capsule.radial_segments = 12
	capsule.rings = 4
	m.mesh = capsule
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	var up: Vector3 = (b - a).normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	m.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)


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
