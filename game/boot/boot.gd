extends Node3D
## WP 1 placeholder scene: proves the web export loads, renders and reports ready.
## Replaced by the title screen in WP 2.

const SPIN_SPEED: float = 0.8

var _cube: MeshInstance3D


func _ready() -> void:
	_build_world()
	_build_overlay()
	Platform.mark_ready()


func _process(delta: float) -> void:
	_cube.rotate_y(delta * SPIN_SPEED)


func _build_world() -> void:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	ground.mesh = plane
	add_child(ground)

	_cube = MeshInstance3D.new()
	_cube.mesh = BoxMesh.new()
	_cube.position = Vector3(0.0, 0.5, 0.0)
	add_child(_cube)

	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 4.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.5, 0.0))


func _build_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	var label: Label = Label.new()
	label.position = Vector2(16.0, 16.0)
	label.text = "Lone Asset — build %s — %s" % [
		ProjectSettings.get_setting("application/config/version"),
		RenderingServer.get_video_adapter_name(),
	]
	layer.add_child(label)
	add_child(layer)
