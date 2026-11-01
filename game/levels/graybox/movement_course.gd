extends Node3D
## Movement and gunplay test course: stairs, steps too high to climb, walkable and too-steep ramps,
## crouch tunnel, low cover, a corner for leaning, jump boxes (WP 3) and a shooting range with
## targets at 10, 25 and 40 m on the right (WP 4). Shows a live tuning readout.

@onready var _player: Player = $Player

var _readout: Label


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	_readout = Label.new()
	_readout.position = Vector2(16.0, 16.0)
	_readout.modulate = Color(1.0, 1.0, 1.0, 0.8)
	layer.add_child(_readout)
	add_child(layer)
	Game.level_ready()


func _process(_delta: float) -> void:
	_readout.text = "%.2f m/s  %s%s  lean %+.2f  %s\nWASD move · Shift sprint · C crouch · Q/E lean · Space jump · LMB fire · RMB aim · R reload · X fire mode · Esc pause" % [
		_player.horizontal_speed,
		StanceComponent.Stance.keys()[_player.stance],
		"  SPRINT" if _player.is_sprinting else "",
		_player.lean_amount,
		"floor" if _player.is_on_floor() else "air",
	]
