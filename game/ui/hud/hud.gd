class_name Hud
extends CanvasLayer
## In-game HUD (design §15), Milestone 1 subset: crosshair that follows weapon spread, ammo and fire
## mode, health, light exposure and a hit marker when the player damages something.

const HIT_MARKER_TIME_S: float = 0.15
const TOAST_TIME_S: float = 3.0

var _player: Player
var _hit_marker_remaining: float = 0.0
var _hit_marker_killed: bool = false
## Recent hits on the player: {position: Vector3 (where the shot came from), age: float}.
var _hits_taken: Array[Dictionary] = []
## 1 right after being hurt, fading to 0.
var _hurt_flash: float = 0.0
var _toast_remaining: float = 0.0

@onready var _crosshair: Control = %Crosshair
@onready var _ammo_label: Label = %AmmoLabel
@onready var _health_label: Label = %HealthLabel
@onready var _exposure_bar: ProgressBar = %ExposureBar
@onready var _indicators: Control = %Indicators
@onready var _objective_list: Label = %ObjectiveList
@onready var _prompt_label: Label = %PromptLabel
@onready var _hold_bar: ProgressBar = %HoldBar
@onready var _toast_label: Label = %ToastLabel
@onready var _vignette: ColorRect = %Vignette

## Where the suspicion arcs sit, in pixels from the crosshair.
const INDICATOR_RADIUS: float = 130.0
const HIT_ARC_RADIUS: float = 105.0
const HIT_ARC_TIME_S: float = 1.5
const HURT_FLASH_RATE: float = 1.8
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
	Mission.changed.connect(_refresh_objectives)
	Mission.objective_completed.connect(_on_objective_completed)
	_toast_label.modulate.a = 0.0
	_refresh_objectives()


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
	_hurt_flash = maxf(_hurt_flash - HURT_FLASH_RATE * delta, 0.0)
	for hit: Dictionary in _hits_taken:
		hit["age"] += delta
	_hits_taken = _hits_taken.filter(func(hit: Dictionary) -> bool: return hit["age"] < HIT_ARC_TIME_S)
	_update_prompt()
	_vignette.modulate.a = _player.binoculars.raise_blend
	_toast_remaining = maxf(_toast_remaining - delta, 0.0)
	_toast_label.modulate.a = clampf(_toast_remaining, 0.0, 1.0)
	_crosshair.queue_redraw()
	_indicators.queue_redraw()


## "[F] Open" for what the player is looking at, with a progress bar while holding a timed use.
func _update_prompt() -> void:
	var focus: Interactable = _player.interactor.focus
	_prompt_label.text = "" if focus == null else "[F]  %s" % focus.prompt_text
	var progress: float = _player.interactor.hold_progress
	_hold_bar.visible = focus != null and focus.definition.hold_duration > 0.0
	_hold_bar.value = progress


func _refresh_objectives() -> void:
	var lines: PackedStringArray = []
	for objective: ObjectiveDefinition in Mission.state.definition.objectives:
		var status: MissionState.Status = Mission.state.status_of(objective.id)
		if status == MissionState.Status.INACTIVE:
			continue
		var mark: String = "[ ]"
		match status:
			MissionState.Status.COMPLETED:
				mark = "[x]"
			MissionState.Status.FAILED:
				mark = "[-]"
		lines.append("%s%s  %s" % [objective.text, "  (optional)" if objective.optional else "", mark])
	_objective_list.text = "\n".join(lines)


func _on_objective_completed(objective: ObjectiveDefinition) -> void:
	if objective.type == ObjectiveDefinition.TYPE_STEALTH:
		return
	_toast_label.text = "OBJECTIVE COMPLETE\n%s" % objective.text
	_toast_remaining = TOAST_TIME_S
	Audio.play_ui(&"objective_complete")


func _on_damage_applied(target: Node, info: DamageInfo, killed: bool) -> void:
	if _player != null and target == _player:
		_hurt_flash = 1.0
		var shooter: Node3D = info.source as Node3D
		if shooter != null:
			_hits_taken.append({"position": shooter.global_position, "age": 0.0})
	if _player != null and info.source == _player:
		_hit_marker_remaining = HIT_MARKER_TIME_S
		_hit_marker_killed = killed
		Audio.play_2d(&"hit_marker", &"UI", 0.0, 0.8 if killed else 1.0)


## Thin cross, a ring that fills while a guard is being tagged, and the zoom level.
func _draw_binocular_reticle(center: Vector2, binoculars: Binoculars) -> void:
	var color: Color = Color(1.0, 1.0, 1.0, 0.8)
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_crosshair.draw_line(center + direction * 6.0, center + direction * 40.0, color, 1.5)
	_crosshair.draw_arc(center, 20.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.25), 1.5)
	if binoculars.tag_progress > 0.0:
		_crosshair.draw_arc(center, 20.0, -PI * 0.5, -PI * 0.5 + TAU * binoculars.tag_progress, 32, Color(1.0, 0.8, 0.2), 4.0)
	var font: Font = ThemeDB.fallback_font
	_crosshair.draw_string(font, center + Vector2(50.0, 50.0), "%dx" % int(binoculars.zoom), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, color)


## Markers over tagged guards. They are drawn on screen, so walls do not hide them.
func _draw_tags() -> void:
	var camera: Camera3D = _player.camera
	var font: Font = ThemeDB.fallback_font
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var guard: Guard = node as Guard
		var time_left: float = _player.binoculars.tag_time_left(guard)
		if time_left <= 0.0 or guard.is_dead:
			continue
		var spot: Vector3 = guard.global_position + Vector3.UP * 2.2
		if camera.is_position_behind(spot):
			continue
		var at: Vector2 = camera.unproject_position(spot)
		var fade: float = clampf(time_left / 5.0, 0.3, 1.0)
		var color: Color = Color(1.0, 0.8, 0.2, fade)
		var points: PackedVector2Array = [at + Vector2(0, 8), at + Vector2(-8, -4), at + Vector2(8, -4)]
		_indicators.draw_colored_polygon(points, color)
		var distance: float = camera.global_position.distance_to(guard.global_position)
		_indicators.draw_string(font, at + Vector2(-16.0, -10.0), "%d m" % roundi(distance), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)


## One arc around the crosshair per suspicious guard, pointing at it. A fuller, thicker arc means more suspicion.
func _draw_indicators() -> void:
	_draw_tags()
	var camera: Camera3D = _player.camera
	var center: Vector2 = _indicators.size * 0.5
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	if _hurt_flash > 0.0:
		_indicators.draw_rect(Rect2(Vector2.ZERO, _indicators.size), Color(0.8, 0.0, 0.0, _hurt_flash * 0.22))
	for hit: Dictionary in _hits_taken:
		var from_shooter: Vector3 = hit["position"] - camera.global_position
		from_shooter.y = 0.0
		if from_shooter.length() < 0.01:
			continue
		var hit_angle: float = -PI * 0.5 - forward.signed_angle_to(from_shooter, Vector3.UP)
		var fade: float = 1.0 - float(hit["age"]) / HIT_ARC_TIME_S
		_indicators.draw_arc(center, HIT_ARC_RADIUS, hit_angle - 0.35, hit_angle + 0.35, 12, Color(1.0, 0.1, 0.1, fade), 8.0)
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
	var binoculars: Binoculars = _player.binoculars
	if binoculars.raise_blend > 0.5:
		_draw_binocular_reticle(center, binoculars)
		return
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
