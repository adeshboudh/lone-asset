extends Control
## Title screen. The Play click is the user gesture that unlocks audio and mouse capture in the browser.

@onready var _play_button: Button = %PlayButton
@onready var _settings_button: Button = %SettingsButton
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_version_label.text = "build %s" % ProjectSettings.get_setting("application/config/version")
	_play_button.pressed.connect(func() -> void: Audio.play_ui(&"ui_click"))
	_play_button.pressed.connect(Game.start_game)
	var settings: SettingsPanel = SettingsPanel.new()
	add_child(settings)
	_settings_button.pressed.connect(func() -> void:
		Audio.play_ui(&"ui_click")
		settings.open())
	settings.closed.connect(_settings_button.grab_focus)
	_play_button.grab_focus()
	Game.enter_title()
	Platform.mark_ready()
