class_name DeathScreen
extends CanvasLayer
## Shown when the player dies. The proper end-of-mission screen arrives in WP 11.

signal retry_requested
signal quit_requested

@onready var _retry_button: Button = %RetryButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_retry_button.pressed.connect(func() -> void: Audio.play_ui(&"ui_click"))
	_quit_button.pressed.connect(func() -> void: Audio.play_ui(&"ui_click"))
	_retry_button.pressed.connect(retry_requested.emit)
	_quit_button.pressed.connect(quit_requested.emit)


func open() -> void:
	visible = true
	_retry_button.grab_focus()


func close() -> void:
	visible = false
