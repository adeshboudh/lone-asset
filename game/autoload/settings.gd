extends Node
## Player settings (design §15), saved to user://settings.cfg (browser storage on the web) and applied
## at once: bus volumes here, the rest read by the player and HUD.

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


func _ready() -> void:
	load_from_disk()
	apply_audio()


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


func save_to_disk() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value(SECTION, "sensitivity", mouse_sensitivity_scale)
	file.set_value(SECTION, "invert_y", invert_y)
	file.set_value(SECTION, "fov", fov_deg)
	file.set_value(SECTION, "head_bob", head_bob)
	file.set_value(SECTION, "master", master_volume)
	file.set_value(SECTION, "music", music_volume)
	file.set_value(SECTION, "sfx", sfx_volume)
	if file.save(PATH) != OK:
		Log.warn(&"settings", "Could not save %s" % PATH)


## Call after changing a value: applies it, saves and tells listeners.
func commit() -> void:
	mouse_sensitivity_scale = SettingsRules.clamp_sensitivity(mouse_sensitivity_scale)
	fov_deg = SettingsRules.clamp_fov(fov_deg)
	apply_audio()
	save_to_disk()
	changed.emit()


func apply_audio() -> void:
	_set_bus(&"Master", master_volume)
	_set_bus(&"Music", music_volume)
	_set_bus(&"SFX", sfx_volume)


func _set_bus(bus_name: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, SettingsRules.volume_db(linear))
