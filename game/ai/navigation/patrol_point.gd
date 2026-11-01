class_name PatrolPoint
extends Marker3D
## One stop on a PatrolRoute (design §10). Place it on the navigation mesh.

@export var wait_time: float = 2.0
## Face look_yaw_deg while waiting. Yaw 0 looks along -Z; positive turns left (counter-clockwise from above).
@export var use_look_direction: bool = false
@export var look_yaw_deg: float = 0.0

var look_direction: Vector3:
	get:
		var yaw: float = deg_to_rad(look_yaw_deg)
		return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _ready() -> void:
	# Marker shown by the F3 debug views.
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.6, 1.0)
	sphere.material = material
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = sphere
	marker.position.y = 0.3
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = bool(get_tree().get_meta(&"debug_views_enabled", false))
	marker.add_to_group(&"debug_view_nodes")
	add_child(marker)
