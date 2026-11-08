class_name Weapon
extends Node3D
## A held weapon (design §5.2): drives WeaponLogic from the input intent, fires through the level's
## BallisticsSystem, returns recoil to the holder and animates the first-person viewmodel.

## Emitted per round, for noise (WP 5), HUD and effects.
signal fired(origin: Vector3, direction: Vector3)

const KICK_DISTANCE: float = 0.035
const KICK_RECOVERY: float = 14.0
const FLASH_TIME_S: float = 0.05
## Raising a weapon after a switch.
const EQUIP_TIME_S: float = 0.35
## World (1) and characters/targets (2): what a blade can hit.
const MELEE_MASK: int = 3

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
var _anim: AnimationPlayer
var _flash: OmniLight3D
var _kick: float = 0.0
var _flash_remaining: float = 0.0
var _was_reloading: bool = false
## 1 right after the weapon is raised, falling to 0.
var _equip: float = 0.0
## Seconds into a melee swing, or -1 when not swinging.
var _melee_t: float = -1.0
var _melee_hit_pending: bool = false
var _melee_heavy: bool = false
var _aim_was_held: bool = false


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


## Raises the weapon after the player switched to it.
func equip() -> void:
	aim_blend = 0.0
	_equip = 1.0
	_melee_t = -1.0
	_play_anim(definition.anim_draw, 0.0)


## False while reloading or swinging: the weapon cannot be put away mid-action.
func can_holster() -> bool:
	return not logic.is_reloading and _melee_t < 0.0


## Returns this tick's recoil kick in radians: x = pitch up, y = yaw.
## moving: 0 = still, 1 = walking speed or faster.
func physics_update(intent: InputIntent, delta: float, shooter: CollisionObject3D, aim: Transform3D,
		moving: float, crouched: bool) -> Vector2:
	if definition.melee:
		return _melee_update(intent, delta, shooter, aim)
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
		var empty: bool = logic.magazine == 0
		_play_anim(definition.anim_reload_empty if empty else definition.anim_reload,
				definition.reload_time_empty if empty else definition.reload_time)
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
		_play_anim(definition.anim_fire, 0.0)
		_flash_remaining = FLASH_TIME_S
		fired.emit(aim.origin, direction)
	return kick


func _process(delta: float) -> void:
	if _viewmodel == null or not is_visible_in_tree():
		return
	_kick = move_toward(_kick, 0.0, KICK_RECOVERY * delta)
	_equip = move_toward(_equip, 0.0, delta / EQUIP_TIME_S)
	var base: Vector3 = definition.viewmodel_hip_position.lerp(definition.viewmodel_ads_position, smoothstep(0.0, 1.0, aim_blend))
	if _anim != null:
		_viewmodel.position = base  # the animations carry the kick and the reload
	else:
		var reload_dip: float = sin(logic.reload_progress() * PI) * 0.12
		var raise: float = _equip * _equip
		var swing: float = sin(clampf(_melee_t / _melee_swing_s(), 0.0, 1.0) * PI) if definition.melee else 0.0
		_viewmodel.position = base + Vector3(-0.10 * swing, -reload_dip - raise * 0.3 + 0.03 * swing, _kick * KICK_DISTANCE + raise * 0.1 - 0.28 * swing)
		_viewmodel.rotation = Vector3(-reload_dip * 2.0 - raise * 0.7 + 0.25 * swing, 0.6 * swing, 0.0)
	_flash_remaining -= delta
	_flash.visible = _flash_remaining > 0.0


## One blade swing: the strike lands part-way through. The fire button swings quickly, the aim button
## makes a slower, longer heavy attack.
func _melee_update(intent: InputIntent, delta: float, shooter: CollisionObject3D, aim: Transform3D) -> Vector2:
	aim_blend = move_toward(aim_blend, 0.0, delta / definition.ads_time)
	current_spread_deg = 0.0
	var heavy_pressed: bool = intent.aim and not _aim_was_held
	_aim_was_held = intent.aim
	if _melee_t < 0.0:
		if intent.fire_pressed or heavy_pressed:
			_melee_heavy = heavy_pressed and not intent.fire_pressed
			_melee_t = 0.0
			_melee_hit_pending = true
			_play_anim(definition.anim_fire_alt if _melee_heavy else definition.anim_fire, _melee_swing_s())
		return Vector2.ZERO
	_melee_t += delta
	var hit_delay: float = definition.melee_heavy_hit_delay_s if _melee_heavy else definition.melee_hit_delay_s
	if _melee_hit_pending and _melee_t >= hit_delay:
		_melee_hit_pending = false
		_strike(shooter, aim)
	if _melee_t >= _melee_swing_s():
		_melee_t = -1.0
	return Vector2.ZERO


func _melee_swing_s() -> float:
	return definition.melee_heavy_swing_s if _melee_heavy else definition.melee_swing_s


func _strike(shooter: CollisionObject3D, aim: Transform3D) -> void:
	var forward: Vector3 = -aim.basis.z
	fired.emit(aim.origin, forward)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		aim.origin, aim.origin + forward * (definition.melee_heavy_range_m if _melee_heavy else definition.melee_range_m), MELEE_MASK, [shooter.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	var health: HealthComponent = HealthComponent.of(collider)
	Audio.play_3d(&"impact_world" if health == null else &"impact_body", hit["position"], &"Weapons", -2.0, shooter)
	if health == null:
		return
	var target: Node3D = collider as Node3D
	var from_behind: bool = target != null and MeleeRules.is_from_behind(
		-target.global_basis.z, shooter.global_position - target.global_position, definition.melee_backstab_arc_deg)
	var info: DamageInfo = DamageInfo.new()
	info.type = &"melee"
	info.source = shooter
	info.hit_position = hit["position"]
	info.hit_normal = hit["normal"]
	info.direction = forward
	info.hit_zone = &"torso"
	info.amount = MeleeRules.damage_for(definition, from_behind, _melee_heavy)
	health.apply_damage(info)


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
	_anim = _viewmodel.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if _anim == null:
		_anim = _viewmodel.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		_play_anim(definition.anim_draw, 0.0)


## Plays a viewmodel animation, then falls back to idle. duration_s > 0 stretches it to that length.
func _play_anim(anim_name: StringName, duration_s: float) -> void:
	if _anim == null or anim_name == &"" or not _anim.has_animation(anim_name):
		return
	var speed: float = ViewmodelAnimationRules.speed_for(_anim.get_animation(anim_name).length, duration_s)
	_anim.stop()
	_anim.play(anim_name, -1.0, speed)
	if definition.anim_idle != &"" and _anim.has_animation(definition.anim_idle):
		_anim.queue(definition.anim_idle)
