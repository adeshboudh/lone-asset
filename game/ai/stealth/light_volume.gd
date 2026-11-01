class_name LightVolume
extends Area3D
## Designer-placed box of authored light (design §9.1): the stealth system cannot read GPU lighting
## cheaply on the web, so light level is data. Overlapping volumes: highest priority wins.

@export_range(0.0, 1.0) var light_level: float = 0.5
@export var light_priority: int = 0
@export var size: Vector3 = Vector3(4.0, 3.0, 4.0)

var _debug_mesh: MeshInstance3D


func _ready() -> void:
	# Detects characters only (physics layer 2).
	collision_layer = 0
	collision_mask = 2

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tint: Color = Color(0.1, 0.15, 0.55).lerp(Color(1.0, 0.85, 0.3), light_level)
	material.albedo_color = Color(tint, 0.22)
	box.material = material
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.mesh = box
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_mesh.visible = bool(get_tree().get_meta(&"debug_views_enabled", false))
	_debug_mesh.add_to_group(&"debug_view_nodes")
	add_child(_debug_mesh)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var exposure: ExposureComponent = body.get_node_or_null(^"ExposureComponent") as ExposureComponent
	if exposure != null:
		exposure.volume_entered(self)


func _on_body_exited(body: Node3D) -> void:
	var exposure: ExposureComponent = body.get_node_or_null(^"ExposureComponent") as ExposureComponent
	if exposure != null:
		exposure.volume_exited(self)
