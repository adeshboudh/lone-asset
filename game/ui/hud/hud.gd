class_name Hud
extends CanvasLayer
## In-game HUD (design §15), Milestone 1 subset: crosshair that follows weapon spread, ammo and fire
## mode, health, light exposure and a hit marker when the player damages something.

const HIT_MARKER_TIME_S: float = 0.15

var _player: Player
var _hit_marker_remaining: float = 0.0
var _hit_marker_killed: bool = false

@onready var _crosshair: Control = %Crosshair
@onready var _ammo_label: Label = %AmmoLabel
@onready var _health_label: Label = %HealthLabel
@onready var _exposure_bar: ProgressBar = %ExposureBar


func setup(player: Player) -> void:
	_player = player
	_crosshair.draw.connect(_draw_crosshair)
	EventBus.damage_applied.connect(_on_damage_applied)


func _process(delta: float) -> void:
	if _player == null:
		return
	var weapon: Weapon = _player.weapon
	var logic: WeaponLogic = weapon.logic
	var status: String = "RELOADING" if logic.is_reloading else String(logic.fire_mode).to_upper()
	_ammo_label.text = "%d / %d   %s" % [logic.magazine, logic.reserve, status]
	_health_label.text = "%d" % ceili(_player.health.health)
	_exposure_bar.value = _player.exposure.exposure
	_hit_marker_remaining = maxf(_hit_marker_remaining - delta, 0.0)
	_crosshair.queue_redraw()


func _on_damage_applied(_target: Node, info: DamageInfo, killed: bool) -> void:
	if _player != null and info.source == _player:
		_hit_marker_remaining = HIT_MARKER_TIME_S
		_hit_marker_killed = killed
		Audio.play_2d(&"hit_marker", &"UI", 0.0, 0.8 if killed else 1.0)


func _draw_crosshair() -> void:
	var center: Vector2 = _crosshair.size * 0.5
	var weapon: Weapon = _player.weapon
	var color: Color = Color(1.0, 1.0, 1.0, 0.85 * (1.0 - weapon.aim_blend))
	# Gap in pixels where the spread cone meets the screen.
	var camera: Camera3D = _player.camera
	var half_height: float = _crosshair.size.y * 0.5
	var gap: float = tan(deg_to_rad(weapon.current_spread_deg)) / tan(deg_to_rad(camera.fov * 0.5)) * half_height
	gap = maxf(gap, 3.0)
	var length: float = 8.0
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_crosshair.draw_line(center + direction * gap, center + direction * (gap + length), color, 2.0)
	if weapon.aim_blend > 0.5:
		_crosshair.draw_circle(center, 1.5, Color(1.0, 1.0, 1.0, 0.9))

	if _hit_marker_remaining > 0.0:
		var marker_color: Color = Color(1.0, 0.3, 0.25) if _hit_marker_killed else Color.WHITE
		for diagonal: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var d: Vector2 = diagonal.normalized()
			_crosshair.draw_line(center + d * 6.0, center + d * 13.0, marker_color, 2.0)
