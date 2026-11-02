extends Node
## Player settings (design §15), saved to user://settings.cfg and applied
## at once: bus volumes and graphics here, the rest read by the player and HUD.

signal changed

const PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

var mouse_sensitivity_scale: float = 1.0
var invert_y: bool = false
var fov_deg: float = 75.0
var head_bob: bool = true
var master_volume: float = 0.8
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var quality: int = SettingsRules.Quality.MEDIUM
var render_scale: float = 1.0


func _ready() -> void:
	load_from_disk()
	apply_audio()
	apply_graphics()


func load_from_disk() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(PATH) != OK:
		return
	mouse_sensitivity_scale = SettingsRules.clamp_sensitivity(file.get_value(SECTION, "sensitivity", mouse_sensitivity_scale))
	invert_y = file.get_value(SECTION, "invert_y", invert_y)
	fov_deg = SettingsRules.clamp_fov(file.get_value(SECTION, "fov", fov_deg))
	head_bob = file.get_value(SECTION, "head_bob", head_bob)
	master_volume = clampf(file.get_value(SECTION, "master", master_volume), 0.0, 1.0)
	music_volume = clampf(file.get_value(SECTION, "music", music_volume), 0.0, 1.0)
	sfx_volume = clampf(file.get_value(SECTION, "sfx", sfx_volume), 0.0, 1.0)
	quality = clampi(file.get_value(SECTION, "quality", quality), SettingsRules.Quality.LOW, SettingsRules.Quality.HIGH)
	render_scale = SettingsRules.clamp_render_scale(file.get_value(SECTION, "render_scale", render_scale))


func save_to_disk() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value(SECTION, "sensitivity", mouse_sensitivity_scale)
	file.set_value(SECTION, "invert_y", invert_y)
	file.set_value(SECTION, "fov", fov_deg)
	file.set_value(SECTION, "head_bob", head_bob)
	file.set_value(SECTION, "master", master_volume)
	file.set_value(SECTION, "music", music_volume)
	file.set_value(SECTION, "sfx", sfx_volume)
	file.set_value(SECTION, "quality", quality)
	file.set_value(SECTION, "render_scale", render_scale)
	if file.save(PATH) != OK:
		Log.warn(&"settings", "Could not save %s" % PATH)


## Call after changing a value: applies it, saves and tells listeners.
func commit() -> void:
	mouse_sensitivity_scale = SettingsRules.clamp_sensitivity(mouse_sensitivity_scale)
	fov_deg = SettingsRules.clamp_fov(fov_deg)
	render_scale = SettingsRules.clamp_render_scale(render_scale)
	apply_audio()
	apply_graphics()
	save_to_disk()
	changed.emit()


func apply_audio() -> void:
	_set_bus(&"Master", master_volume)
	_set_bus(&"Music", music_volume)
	_set_bus(&"SFX", sfx_volume)


## Applies the quality preset and render scale to the window and to every WorldEnvironment in the
## current scene. Levels call it again once loaded (Game.level_ready).
func apply_graphics() -> void:
	var values: Dictionary = SettingsRules.preset(quality)
	var viewport: Viewport = get_tree().root
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale
	viewport.msaa_3d = Viewport.MSAA_2X if int(values["msaa"]) == 2 else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if values["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(int(values["shadow_size"]), true)
	var soft: RenderingServer.ShadowQuality = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][int(values["soft_shadows"])]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)
	for node: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = (node as WorldEnvironment).environment
		if environment != null:
			environment.ssao_enabled = values["ssao"]
			environment.glow_enabled = values["glow"]


func _set_bus(bus_name: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, SettingsRules.volume_db(linear))
