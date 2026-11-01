class_name NoiseSensor
extends Node3D
## Test prop: a post that shows what it hears. Stands in for a guard's ears until WP 7.

const HEARD_COLOR: Color = Color(0.4, 1.0, 0.5)
const IDLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const SHOW_TIME_S: float = 1.5

@export var title: String = "SENSOR"

@onready var _listener: NoiseListener = $NoiseListener
@onready var _label: Label3D = $Label

var _tween: Tween


func _ready() -> void:
	_label.text = title
	_label.modulate = IDLE_COLOR
	_listener.heard.connect(_on_heard)


func _on_heard(event: NoiseEvent, distance: float, walls: int) -> void:
	_label.text = "%s\nheard %s\n%.1f m, %d wall(s)" % [title, event.type, distance, walls]
	_label.modulate = HEARD_COLOR
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SHOW_TIME_S)
	_tween.tween_callback(func() -> void:
		_label.text = title
		_label.modulate = IDLE_COLOR)
