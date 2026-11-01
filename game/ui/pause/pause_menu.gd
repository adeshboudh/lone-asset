class_name PauseMenu
extends CanvasLayer
## Pause overlay. Resume asks Game to re-capture the mouse; the game unpauses once the browser grants it.

signal resume_requested
signal quit_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _quit_button: Button = %QuitButton
@onready var _capture_hint: Label = %CaptureHint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_button.pressed.connect(resume_requested.emit)
	_quit_button.pressed.connect(quit_requested.emit)


func open() -> void:
	_capture_hint.visible = false
	visible = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false


## Shown when the browser refused the mouse capture, e.g. clicking Resume right after pressing Esc.
func show_capture_hint() -> void:
	_capture_hint.visible = true
