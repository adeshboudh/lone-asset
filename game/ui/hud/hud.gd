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
@onready var _indicators: Control = %Indicators

## Where the suspicion arcs sit, in pixels from the crosshair.
const INDICATOR_RADIUS: float = 130.0
## Arc colour by suspicion band (design §9.5). Normal shows nothing.
const BAND_COLORS: Dictionary[SuspicionRules.Band, Color] = {
	SuspicionRules.Band.CURIOUS: Color(1.0, 1.0, 1.0),
	SuspicionRules.Band.SUSPICIOUS: Color(1.0, 0.9, 0.2),
	SuspicionRules.Band.SEARCHING: Color(1.0, 0.55, 0.1),
	SuspicionRules.Band.COMBAT: Color(1.0, 0.2, 0.15),
}


func setup(player: Player) -> void:
	_player = player
	_crosshair.draw.connect(_draw_crosshair)
	_indicators.draw.connect(_draw_indicators)
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
	_indicators.queue_redraw()


func _on_damage_applied(_target: Node, info: DamageInfo, killed: bool) -> void:
	if _player != null and info.source == _player:
		_hit_marker_remaining = HIT_MARKER_TIME_S
		_hit_marker_killed = killed
		Audio.play_2d(&"hit_marker", &"UI", 0.0, 0.8 if killed else 1.0)


## One arc around the crosshair per suspicious guard, pointing at it. A fuller, thicker arc means more suspicion.
func _draw_indicators() -> void:
	var camera: Camera3D = _player.camera
	var center: Vector2 = _indicators.size * 0.5
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var guard: Guard = node as Guard
		if guard.is_dead or not BAND_COLORS.has(guard.suspicion.band):
			continue
		var to_guard: Vector3 = guard.global_position - camera.global_position
		to_guard.y = 0.0
		if to_guard.length() < 0.01:
			continue
		# Up on screen is -PI/2; a guard to the left (positive signed angle) is counter-clockwise from there.
		var angle: float = -PI * 0.5 - forward.signed_angle_to(to_guard, Vector3.UP)
		var t: float = guard.suspicion.value / SuspicionRules.MAX_SUSPICION
		var color: Color = BAND_COLORS[guard.suspicion.band]
		color.a = lerpf(0.5, 1.0, t)
		var half_span: float = lerpf(0.12, 0.45, t)
		_indicators.draw_arc(center, INDICATOR_RADIUS, angle - half_span, angle + half_span, 14, color, lerpf(3.0, 11.0, t))


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
