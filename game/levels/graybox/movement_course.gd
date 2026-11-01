extends Node3D
## Movement and gunplay test course: stairs, steps too high to climb, walkable and too-steep ramps,
## crouch tunnel, low cover, a corner for leaning, jump boxes (WP 3) and a shooting range with
## targets at 10, 25 and 40 m on the right (WP 4), and stealth test spots (WP 5): light zones
## (tunnel, shadow behind the low cover, floodlit range), noise sensors either side of a wall,
## and metal / grass floor patches. Press F3 for noise rings and light volumes.
## WP 9 adds the compound in the north-west corner (two doors, a data terminal, a guard inside) and
## the extraction zone in the south-east, with the mission that ties them together.

const MISSION: MissionDefinition = preload("res://data/missions/m1_prototype.tres")

@onready var _player: Player = $Player

var _readout: Label


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	_readout = Label.new()
	_readout.position = Vector2(16.0, 16.0)
	_readout.modulate = Color(1.0, 1.0, 1.0, 0.8)
	layer.add_child(_readout)
	add_child(layer)
	var wind: AudioStreamPlayer = Audio.make_loop(&"wind_loop", &"Ambience", -14.0)
	if wind != null:
		add_child(wind)
	Mission.start(MISSION)
	Game.level_ready()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_readout.text = "%.2f m/s  %s%s  lean %+.2f  %s\nWASD move · Shift sprint · C crouch · Q/E lean · Space jump · LMB fire · RMB aim · R reload · X fire mode · F use · B binoculars (wheel zoom, hold on a guard to tag) · F3 debug · Esc pause" % [
		_player.horizontal_speed,
		StanceComponent.Stance.keys()[_player.stance],
		"  SPRINT" if _player.is_sprinting else "",
		_player.lean_amount,
		"floor" if _player.is_on_floor() else "air",
	]
