extends Control
## Title screen: Continue (when a checkpoint exists), New game and Settings.

@onready var _play_button: Button = %PlayButton
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _version_label: Label = %VersionLabel


static var _benchmark_started: bool = false


func _ready() -> void:
	_version_label.text = "build %s" % ProjectSettings.get_setting("application/config/version")
	_play_button.set_meta(UiSounds.META, &"ui_start")
	_continue_button.set_meta(UiSounds.META, &"ui_start")
	_continue_button.visible = Saves.has_checkpoint()
	var settings: SettingsPanel = SettingsPanel.new()
	add_child(settings)
	_settings_button.pressed.connect(settings.open)
	settings.closed.connect(_settings_button.grab_focus)
	settings.closed.connect(func() -> void: _continue_button.visible = Saves.has_checkpoint())
	(_continue_button if _continue_button.visible else _play_button).grab_focus()
	# After the first focus, so opening the screen is silent. Before the actions, so a click sounds even when the
	# action leaves the screen.
	UiSounds.wire(self)
	_play_button.pressed.connect(Game.start_game)
	_continue_button.pressed.connect(Game.continue_game)
	Game.enter_title()
	if OS.get_cmdline_user_args().has("--benchmark") and not _benchmark_started:
		_benchmark_started = true
		Game.start_benchmark.call_deferred()
	Platform.mark_ready()
