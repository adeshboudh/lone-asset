extends Node
## Developer overlay toggled with F3 (design §15): noise rings, light volumes and a stealth readout.
## Global because the toggle and the readout belong to no single level. Milestone 1 previews keep it
## enabled for playtesting; before a public release it is restricted to development builds.

const RING_TIME_S: float = 0.8
const RING_COLORS: Dictionary[StringName, Color] = {
	NoiseEvent.FOOTSTEP_WALK: Color(1.0, 1.0, 1.0),
	NoiseEvent.FOOTSTEP_SPRINT: Color(1.0, 1.0, 1.0),
	NoiseEvent.FOOTSTEP_CROUCH: Color(1.0, 1.0, 1.0),
	NoiseEvent.LANDING: Color(1.0, 0.6, 0.2),
	NoiseEvent.SHOT_SUPPRESSED: Color(1.0, 0.3, 0.3),
	NoiseEvent.SHOT: Color(1.0, 0.1, 0.1),
	NoiseEvent.DOOR: Color(0.5, 0.8, 1.0),
	NoiseEvent.IMPACT: Color(1.0, 0.9, 0.3),
}

var enabled: bool = false

var _readout: Label
var _ring_mesh: TorusMesh
var _last_noise: NoiseEvent


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_meta(&"debug_views_enabled", false)

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 20
	_readout = Label.new()
	_readout.visible = false
	_readout.position = Vector2(16.0, 80.0)
	_readout.add_theme_color_override(&"font_color", Color(0.7, 1.0, 0.8))
	_readout.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	_readout.add_theme_constant_override(&"shadow_offset_x", 1)
	_readout.add_theme_constant_override(&"shadow_offset_y", 1)
	layer.add_child(_readout)
	add_child(layer)

	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.97
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 64
	_ring_mesh.ring_segments = 4

	EventBus.noise_emitted.connect(_on_noise)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_views"):
		set_enabled(not enabled)


func set_enabled(value: bool) -> void:
	enabled = value
	get_tree().set_meta(&"debug_views_enabled", value)
	_readout.visible = value
	for node: Node in get_tree().get_nodes_in_group(&"debug_view_nodes"):
		(node as Node3D).visible = value


func _process(_delta: float) -> void:
	if not enabled:
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	var lines: PackedStringArray = ["DEBUG VIEWS (F3)"]
	if player != null:
		var volume: LightVolume = player.exposure.active_volume
		lines.append("light level %.2f   exposure %.2f" % [player.exposure.light_level, player.exposure.exposure])
		lines.append("light source: %s" % (String(volume.name) if volume != null else "ambient"))
	lines.append("perception: %.2f ms, %d rays this tick (most %d, budget %d)" % [
		PerceptionScheduler.average_ms, PerceptionScheduler.rays_last_tick,
		PerceptionScheduler.max_rays_per_tick, PerceptionScheduler.RAY_BUDGET])
	if _last_noise != null:
		lines.append("last noise: %s  %.1f m" % [_last_noise.type, _last_noise.radius_m])
	_readout.text = "\n".join(lines)


func _on_noise(event: NoiseEvent) -> void:
	_last_noise = event
	if enabled and event.radius_m > 0.0:
		_spawn_ring(event)


func _spawn_ring(event: NoiseEvent) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var color: Color = RING_COLORS.get(event.type, Color.WHITE)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.9)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(ring)
	ring.global_position = event.position + Vector3.UP * 0.06
	ring.scale = Vector3(event.radius_m, 1.0, event.radius_m)
	var tween: Tween = ring.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, RING_TIME_S)
	tween.tween_callback(ring.queue_free)
