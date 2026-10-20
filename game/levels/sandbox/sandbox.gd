extends Node3D
## WP 2 test level: proves mouse capture, mouse look and pausing. Replaced by the graybox level in WP 3.

const SPIN_SPEED: float = 0.8
const MOUSE_SENSITIVITY: float = 0.0025
const MAX_PITCH: float = deg_to_rad(85.0)

var _cube: MeshInstance3D
var _camera: Camera3D


func _ready() -> void:
	_build_world()
	_build_overlay()
	Game.level_ready()


func _process(delta: float) -> void:
	_cube.rotate_y(delta * SPIN_SPEED)


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or not Platform.is_mouse_captured():
		return
	_camera.rotation.y -= motion.relative.x * MOUSE_SENSITIVITY
	_camera.rotation.x = clampf(_camera.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, -MAX_PITCH, MAX_PITCH)


func _build_world() -> void:
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
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
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	add_child(ground)

	_cube = MeshInstance3D.new()
	_cube.mesh = BoxMesh.new()
	_cube.position = Vector3(0.0, 0.5, -4.0)
	add_child(_cube)

	for i: int in 8:
		var pillar: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.6, 3.0, 0.6)
		pillar.mesh = box
		var angle: float = TAU * i / 8.0
		pillar.position = Vector3(cos(angle) * 10.0, 1.5, sin(angle) * 10.0)
		add_child(pillar)

	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 1.65, 0.0)
	add_child(_camera)


func _build_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	var label: Label = Label.new()
	label.position = Vector2(16.0, 16.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	label.text = "Move the mouse to look around. Esc pauses.\n%s" % RenderingServer.get_video_adapter_name()
	layer.add_child(label)
	add_child(layer)
