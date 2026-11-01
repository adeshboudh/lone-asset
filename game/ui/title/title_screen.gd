extends Control
## Title screen. The Play click is the user gesture that unlocks audio and mouse capture in the browser.

@onready var _play_button: Button = %PlayButton
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_version_label.text = "build %s" % ProjectSettings.get_setting("application/config/version")
	_play_button.pressed.connect(Game.start_game)
	_play_button.grab_focus()
	Game.enter_title()
	Platform.mark_ready()
