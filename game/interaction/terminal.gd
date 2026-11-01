class_name Terminal
extends Node3D
## A data terminal (design §12): hold the interact key for the download to finish. A hum plays while
## the download runs; letting go or taking damage cancels it.

const DONE_COLOR: Color = Color(0.2, 1.0, 0.35)

@export var terminal_id: StringName

var is_downloaded: bool = false

var _hum: AudioStreamPlayer

@onready var _interactable: Interactable = %Interactable
@onready var _screen: MeshInstance3D = %Screen
@onready var _status: Label3D = %Status


func _ready() -> void:
	add_to_group(&"terminals")
	_interactable.interactable_id = terminal_id
	_interactable.hold_started.connect(_on_hold_started)
	_interactable.hold_stopped.connect(_stop_hum)
	_interactable.completed.connect(_on_completed)


func _on_hold_started(_actor: Node) -> void:
	_stop_hum(null)
	_hum = Audio.make_loop(&"terminal_loop", &"SFX", -8.0)
	if _hum != null:
		add_child(_hum)
	_status.text = "DOWNLOADING..."


func _stop_hum(_actor: Node) -> void:
	if _hum != null:
		_hum.queue_free()
		_hum = null
	if not is_downloaded:
		_status.text = "DATA TERMINAL"


func save_state() -> Dictionary:
	return {"downloaded": is_downloaded}


func load_state(data: Dictionary) -> void:
	if bool(data.get("downloaded", false)):
		_mark_done()
		_interactable.enabled = false


func _on_completed(_actor: Node) -> void:
	_mark_done()
	Audio.play_3d(&"terminal_done", global_position)


func _mark_done() -> void:
	is_downloaded = true
	_stop_hum(null)
	_status.text = "DOWNLOAD COMPLETE"
	var material: StandardMaterial3D = _screen.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = DONE_COLOR
		material.emission = DONE_COLOR
