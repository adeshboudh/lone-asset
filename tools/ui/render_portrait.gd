# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
extends Node3D
## Renders the agent's head-and-shoulders portrait for the inventory and menu (needs a window, not --headless):
##   godot --path . res://tools/ui/render_portrait.tscn
## Writes content/ui/portraits/agent_portrait.png (transparent background, cold low-key light with a green rim).

const OUT_PATH: String = "res://content/ui/portraits/agent_portrait.png"
const SIZE: Vector2i = Vector2i(512, 640)
## Where the camera looks (model space, metres): the neck, so the head and shoulders fill the frame.
const FOCUS: Vector3 = Vector3(0.0, 1.62, 0.0)
const DISTANCE_M: float = 1.75
const FOV_DEG: float = 28.0


func _ready() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var model: Node3D = (load("res://content/characters/agent/agent_body.glb") as PackedScene).instantiate()
	viewport.add_child(model)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.38, 0.42)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	# Key from the front-left, dim and cool; a green rim from behind-right; a soft fill from below-right.
	viewport.add_child(_light(Vector3(-35.0, 25.0, 0.0), Color(0.78, 0.86, 1.0), 1.1))
	viewport.add_child(_light(Vector3(-20.0, 150.0, 0.0), Color(0.24, 0.86, 0.37), 0.9))
	viewport.add_child(_light(Vector3(25.0, -35.0, 0.0), Color(0.6, 0.7, 0.8), 0.25))
	var camera: Camera3D = Camera3D.new()
	camera.fov = FOV_DEG
	camera.current = true
	viewport.add_child(camera)
	camera.position = FOCUS + Vector3(0.0, 0.03, DISTANCE_M)
	camera.look_at(FOCUS, Vector3.UP)
	for i: int in 6:
		await get_tree().process_frame
	var image: Image = viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH).get_base_dir())
	var error: Error = image.save_png(ProjectSettings.globalize_path(OUT_PATH))
	print("PORTRAIT ", OUT_PATH, " ", image.get_size(), " -> ", error_string(error))
	get_tree().quit()


func _light(rotation_deg: Vector3, color: Color, energy: float) -> DirectionalLight3D:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = rotation_deg
	light.light_color = color
	light.light_energy = energy
	return light
