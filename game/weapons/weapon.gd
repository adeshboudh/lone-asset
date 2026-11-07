class_name Weapon
extends Node3D
## A held weapon (design §5.2): drives WeaponLogic from the input intent, fires through the level's
## BallisticsSystem, returns recoil to the holder and animates the first-person viewmodel.

## Emitted per round, for noise (WP 5), HUD and effects.
signal fired(origin: Vector3, direction: Vector3)

const HIP_POSITION: Vector3 = Vector3(0.16, -0.17, -0.32)
const ADS_POSITION: Vector3 = Vector3(0.0, -0.105, -0.24)
const KICK_DISTANCE: float = 0.035
const KICK_RECOVERY: float = 14.0
const FLASH_TIME_S: float = 0.05

@export var definition: WeaponDefinition
## Seed for spread randomness; 0 picks a random seed.
@export var rng_seed: int = 0

var logic: WeaponLogic
var spread: WeaponSpread = WeaponSpread.new()
## 0 = hip, 1 = fully aimed.
var aim_blend: float = 0.0
## Spread right now, for the crosshair (degrees, cone half-angle).
var current_spread_deg: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ballistics: BallisticsSystem
var _viewmodel: Node3D
var _flash: OmniLight3D
var _kick: float = 0.0
var _turn_rate: Vector2 = Vector2.ZERO
var _strafe_speed: float = 0.0
var _ground_speed: float = 0.0
var _grounded: bool = true
var _bob_phase: float = 0.0
var _sway_position: Vector3 = Vector3.ZERO
var _sway_rotation_deg: Vector3 = Vector3.ZERO
var _flash_remaining: float = 0.0
var _was_reloading: bool = false


func _ready() -> void:
	logic = WeaponLogic.new(definition)
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_ballistics = get_tree().get_first_node_in_group(BallisticsSystem.GROUP) as BallisticsSystem
	if _ballistics == null:
		Log.warn(&"weapon", "No BallisticsSystem in the level; %s cannot fire" % definition.id)
	_build_viewmodel()


## Called by the holder every frame: turn rate in rad/s (x yaw right-positive, y pitch up-positive)
## strafe speed in m/s (right-positive), horizontal speed in m/s and whether the player is on the
## floor. Drives the viewmodel sway and walk bob.
func set_sway_input(turn_rate: Vector2, strafe_speed: float, ground_speed: float, grounded: bool) -> void:
	_turn_rate = turn_rate
	_strafe_speed = strafe_speed
	_ground_speed = ground_speed
	_grounded = grounded


## Returns this tick's recoil kick in radians: x = pitch up, y = yaw.
## moving: 0 = still, 1 = walking speed or faster.
func physics_update(intent: InputIntent, delta: float, shooter: CollisionObject3D, aim: Transform3D,
		moving: float, crouched: bool) -> Vector2:
	var wants_aim: bool = intent.aim and not logic.is_reloading
	aim_blend = move_toward(aim_blend, 1.0 if wants_aim else 0.0, delta / definition.ads_time)
	if intent.fire_mode_toggled:
		logic.toggle_fire_mode()
	if intent.reload:
		logic.start_reload()

	if intent.fire_pressed and logic.magazine == 0 and logic.reserve == 0 and not logic.is_reloading:
		Audio.play_2d(definition.dry_fire_sound, &"Weapons")

	spread.update(definition, delta)
	var aiming: bool = aim_blend > 0.5
	current_spread_deg = spread.current_deg(definition, aiming, moving, crouched)

	var kick: Vector2 = Vector2.ZERO
	var shots: int = logic.update(delta, intent.fire, intent.fire_pressed) if _ballistics != null else 0
	if logic.is_reloading and not _was_reloading:
		Audio.play_2d(definition.reload_empty_sound if logic.magazine == 0 else definition.reload_sound, &"Weapons")
	_was_reloading = logic.is_reloading
	for i: int in shots:
		var direction: Vector3 = WeaponSpread.random_direction(-aim.basis.z, current_spread_deg, _rng)
		_ballistics.fire(aim.origin, direction, definition, shooter)
		Audio.play_2d(definition.fire_sound, &"Weapons", 0.0, _rng.randf_range(0.96, 1.04))
		spread.on_shot(definition)
		current_spread_deg = spread.current_deg(definition, aiming, moving, crouched)
		var recoil_scale: float = lerpf(1.0, definition.recoil_ads_mult, aim_blend)
		kick += Vector2(
			deg_to_rad(definition.recoil_pitch_deg),
			deg_to_rad(_rng.randf_range(-definition.recoil_yaw_deg, definition.recoil_yaw_deg))) * recoil_scale
		_kick = 1.0
		_flash_remaining = FLASH_TIME_S
		fired.emit(aim.origin, direction)
	return kick


func _process(delta: float) -> void:
	if _viewmodel == null:
		return
	_kick = move_toward(_kick, 0.0, KICK_RECOVERY * delta)
	var reload_dip: float = sin(logic.reload_progress() * PI) * 0.12
	_sway_position = WeaponSwayRules.approach(_sway_position,
		WeaponSwayRules.target_position(definition, _turn_rate, _strafe_speed, aim_blend), definition.sway_smoothing, delta)
	_sway_rotation_deg = WeaponSwayRules.approach(_sway_rotation_deg,
		WeaponSwayRules.target_rotation_deg(definition, _turn_rate, _strafe_speed, aim_blend), definition.sway_smoothing, delta)
	_bob_phase = WeaponSwayRules.advance_bob_phase(definition, _bob_phase, _ground_speed, _grounded, delta)
	var bob_position: Vector3 = WeaponSwayRules.bob_position(definition, _bob_phase, _ground_speed, _grounded, aim_blend)
	var bob_rotation_deg: Vector3 = WeaponSwayRules.bob_rotation_deg(definition, _bob_phase, _ground_speed, _grounded, aim_blend)
	var rotation_deg: Vector3 = _sway_rotation_deg + bob_rotation_deg
	_viewmodel.position = HIP_POSITION.lerp(ADS_POSITION, smoothstep(0.0, 1.0, aim_blend)) \
		+ Vector3(0.0, -reload_dip, _kick * KICK_DISTANCE) + _sway_position + bob_position
	_viewmodel.rotation = Vector3(-reload_dip * 2.0, 0.0, 0.0) + Vector3(
		deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y), deg_to_rad(rotation_deg.z))
	_flash_remaining -= delta
	_flash.visible = _flash_remaining > 0.0


func _build_viewmodel() -> void:
	if definition.viewmodel_scene == null:
		return
	_viewmodel = definition.viewmodel_scene.instantiate()
	add_child(_viewmodel)
	for node: Node in _viewmodel.find_children("*", "GeometryInstance3D"):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.5)
	_flash.light_energy = 0.6 if definition.suppressed else 2.5
	_flash.omni_range = 2.5
	_flash.visible = false
	var muzzle: Node3D = _viewmodel.get_node_or_null(^"Muzzle") as Node3D
	(muzzle if muzzle != null else _viewmodel).add_child(_flash)
