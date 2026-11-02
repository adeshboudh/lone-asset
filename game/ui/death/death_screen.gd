class_name DeathScreen
extends CanvasLayer
## End-of-mission screen: shown when the player dies or completes the mission. The proper version
## (stats, ranks) arrives in WP 11.

signal retry_requested
signal quit_requested

@onready var _retry_button: Button = %RetryButton
@onready var _quit_button: Button = %QuitButton
@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _tint: ColorRect = %Tint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_retry_button.pressed.connect(func() -> void: Audio.play_ui(&"ui_click"))
	_quit_button.pressed.connect(func() -> void: Audio.play_ui(&"ui_click"))
	_retry_button.pressed.connect(retry_requested.emit)
	_quit_button.pressed.connect(quit_requested.emit)


func open(success: bool = false, summary: String = "") -> void:
	_title.text = "MISSION COMPLETE" if success else "ELIMINATED"
	_tint.color = Color(0.02, 0.25, 0.1, 0.7) if success else Color(0.35, 0.02, 0.02, 0.7)
	_retry_button.text = "Play again" if success else ("Retry from checkpoint" if Saves.has_checkpoint() else "Retry")
	_summary.text = summary
	_summary.visible = not summary.is_empty()
	visible = true
	_retry_button.grab_focus()


func close() -> void:
	visible = false
