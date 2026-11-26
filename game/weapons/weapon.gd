class_name Weapon
extends Node3D
## A held weapon (design §5.2): drives WeaponLogic from the input intent, fires through the level's
## BallisticsSystem, returns recoil to the holder and animates the first-person viewmodel.

## Emitted per round, for noise (WP 5), HUD and effects.
signal fired(origin: Vector3, direction: Vector3)

const KICK_DISTANCE: float = 0.035
const KICK_RECOVERY: float = 14.0
const FLASH_TIME_S: float = 0.05
const MUZZLE_FLASH: PackedScene = preload("res://content/effects/muzzle_flash/muzzle_flash.tscn")
const MUZZLE_SMOKE: PackedScene = preload("res://content/effects/muzzle_smoke/muzzle_smoke.tscn")
## World and characters, same as the bullets.
const MUZZLE_RAY_MASK: int = 3
## Procedural switch motion (data/weapons/switch_motion.tres, rules in SwitchMotionRules).
const SWITCH_MOTION: SwitchMotionSettings = preload("res://data/weapons/switch_motion.tres")
## Draw timer value meaning "no draw in progress".
const DRAW_DONE_S: float = 1000.0
## The player's first-person arms, put on the weapon's arm rig (game/player/fps_arms.gd).
const FPS_ARMS: FpsArmsSettings = preload("res://data/player/fps_arms.tres")
## World (1) and characters/targets (2): what a blade can hit.
const MELEE_MASK: int = 3

@export var definition: WeaponDefinition
## Seed for spread randomness; 0 picks a random seed.
@export var rng_seed: int = 0

var logic: WeaponLogic
var spread: WeaponSpread = WeaponSpread.new()
## 0 = hip, 1 = fully aimed.
var aim_blend: float = 0.0
## The same move as the viewmodel and the camera zoom see it: a damped spring toward aiming or not aiming (see
## AdsRules), so it is smooth when the button is released half-way. 0 = hip, 1 = aimed; overshoots a little.
var visual_aim: float = 0.0
## Spread right now, for the crosshair (degrees, cone half-angle).
var current_spread_deg: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ballistics: BallisticsSystem
var _viewmodel: Node3D
var _anim: AnimationPlayer
## The first-person model and its animation player, for the player's body to copy.
var viewmodel: Node3D:
	get:
		return _viewmodel
var animation_player: AnimationPlayer:
	get:
		return _anim
var _flash: OmniLight3D
var _flash_particles: GPUParticles3D
var _flash_quad_size: Vector2
## The voice playing the reload sound and its stream (the pool reuses voices, so the stream is checked before a stop).
var _reload_voice: AudioStreamPlayer
## What the last round fired changed about the shot (read by the holder for the noise).
var last_shot_profile: ShotProfile = ShotProfile.new()
var _reload_stream: AudioStream
var _smoke_quad_size: Vector2
var _smoke_particles: GPUParticles3D
var _muzzle: Node3D
var _kick: float = 0.0
## The gun's spring kick (ViewmodelRecoilRules): position (m) and rotation (deg) with their velocities.
var _kick_position: Vector3 = Vector3.ZERO
var _kick_position_velocity: Vector3 = Vector3.ZERO
var _kick_rotation: Vector3 = Vector3.ZERO
var _kick_rotation_velocity: Vector3 = Vector3.ZERO
var _turn_rate: Vector2 = Vector2.ZERO
var _strafe_speed: float = 0.0
var _ground_speed: float = 0.0
var _stride_m: float = 1.8
var _grounded: bool = true
var _bob_phase: float = 0.0
var _sway_position: Vector3 = Vector3.ZERO
var _sway_rotation_deg: Vector3 = Vector3.ZERO
var _flash_remaining: float = 0.0
var _reload_started_here: bool = false
var _was_reloading: bool = false
## 1 right after the weapon is raised, falling to 0.
var _draw_elapsed_s: float = DRAW_DONE_S
## 0 = in hand, 1 = fully lowered: grows while the weapon is being put away (see begin_holster).
var _holster: float = 0.0
var _holstering: bool = false
## Seconds into a melee swing, or -1 when not swinging.
var _melee_t: float = -1.0
var _melee_hit_pending: bool = false
var _melee_heavy: bool = false
var _aim_was_held: bool = false
var _aim_target: float = 0.0
var _visual_aim_velocity: float = 0.0
## This weapon's versions: the scene's definition first, then its alt_variant (if any).
var _variants: Array[WeaponDefinition] = []
var _variant_index: int = 0
## Seconds left in an attachment swap, during which the weapon cannot fire or reload.
var _swap_remaining: float = 0.0

var variant_index: int:
	get:
		return _variant_index

## Id of the scene's definition: the same whichever variant is fitted, so saves find the right slot.
var base_id: StringName:
	get:
		return _variants[0].id if not _variants.is_empty() else definition.id


func _ready() -> void:
	logic = WeaponLogic.new(definition)
	_variants.append(definition)
	if definition.alt_variant != null:
		_variants.append(definition.alt_variant)
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_ballistics = get_tree().get_first_node_in_group(BallisticsSystem.GROUP) as BallisticsSystem
	if _ballistics == null:
		Log.warn(&"weapon", "No BallisticsSystem in the level; %s cannot fire" % definition.id)
	_build_viewmodel()


## The holder's pouches: reloads take magazines from them and return the old one.
func attach_inventory(pouches: AmmoInventory) -> void:
	logic.inventory = pouches


## Called by the holder every frame: turn rate in rad/s (x yaw right-positive, y pitch up-positive)
## strafe speed in m/s (right-positive), horizontal speed in m/s, whether the player is on the
## floor and the current footstep stride in m. Drives the viewmodel sway and walk bob.
func set_sway_input(turn_rate: Vector2, strafe_speed: float, ground_speed: float, grounded: bool, stride_m: float) -> void:
	_turn_rate = turn_rate
	_strafe_speed = strafe_speed
	_ground_speed = ground_speed
	_grounded = grounded
	_stride_m = stride_m


## Raises the weapon after the player switched to it.
func equip() -> void:
	aim_blend = 0.0
	visual_aim = 0.0
	_visual_aim_velocity = 0.0
	_aim_target = 0.0
	_draw_elapsed_s = 0.0
	clear_holster()
	_melee_t = -1.0
	_play_anim(definition.anim_draw, 0.0)


## Starts lowering the weapon so the holder can switch to another one when is_holstered() turns true.
## Reloads with the rig magazine at `rig_index` (the inventory screen's drag onto the gun). False when this weapon
## is not the one in hand, is swapping its attachment, or the logic refuses (`logic.reload_block` says why).
func request_reload_with(rig_index: int) -> bool:
	if not visible or _swap_remaining > 0.0 or definition.melee:
		return false
	return logic.start_reload_with(rig_index)


## A reload under way is abandoned: no ammo is loaded, its sound is cut and the arms go back to the idle clip.
func begin_holster() -> void:
	_holstering = true
	if not logic.is_reloading:
		return
	logic.cancel_reload()
	_was_reloading = false
	if _reload_voice != null and _reload_voice.playing and _reload_voice.stream == _reload_stream:
		_reload_voice.stop()
	if _anim != null and _anim.has_animation(definition.anim_idle):
		_anim.play(definition.anim_idle, SWITCH_MOTION.holster_time_s)


func is_holstered() -> bool:
	return _holstering and _holster >= 1.0


## Back in hand at once (a switch finished, or a saved game was loaded).
func clear_holster() -> void:
	_holstering = false
	_holster = 0.0


## False while swapping the attachment or swinging: the weapon cannot be put away mid-action. A reload can be
## abandoned (begin_holster).
func can_holster() -> bool:
	return _melee_t < 0.0 and _swap_remaining <= 0.0


## True when toggle_variant() would work: this weapon is in hand, has another version and is not busy.
func toggle_variant_allowed() -> bool:
	return visible and LoadoutRules.can_swap_variant(_variants.size() > 1, logic.is_reloading, _swap_remaining > 0.0)


## Swaps to the other version (suppressor <-> muzzle brake). False when there is none or the weapon is busy.
func toggle_variant() -> bool:
	if not LoadoutRules.can_swap_variant(_variants.size() > 1, logic.is_reloading, _swap_remaining > 0.0):
		return false
	set_variant((_variant_index + 1) % _variants.size())
	_swap_remaining = definition.variant_swap_s
	_draw_elapsed_s = 0.0
	_play_anim(definition.anim_draw, 0.0)
	return true


## Selects a version directly (saved games, tests); no delay or animation.
func set_variant(index: int) -> void:
	if _variants.is_empty() or index < 0 or index >= _variants.size():
		return
	_variant_index = index
	definition = _variants[index]
	logic.swap_definition(definition)
	if _viewmodel != null and _viewmodel.has_method(&"show_suppressor"):
		_viewmodel.call(&"show_suppressor", definition.suppressed)
	_apply_muzzle_effects()


## Returns this tick's recoil kick in radians: x = pitch up, y = yaw.
## moving: 0 = still, 1 = walking speed or faster.
func physics_update(intent: InputIntent, delta: float, shooter: CollisionObject3D, aim: Transform3D,
		moving: float, crouched: bool) -> Vector2:
	_holster = move_toward(_holster, 1.0 if _holstering else 0.0, delta / SWITCH_MOTION.holster_time_s)
	if definition.melee:
		return _melee_update(intent, delta, shooter, aim)
	var swapping: bool = _swap_remaining > 0.0
	_swap_remaining = maxf(_swap_remaining - delta, 0.0)
	if intent.attachment_toggled:
		toggle_variant()
		swapping = _swap_remaining > 0.0
	var wants_aim: bool = intent.aim and not logic.is_reloading and not swapping
	aim_blend = move_toward(aim_blend, 1.0 if wants_aim else 0.0, delta / definition.ads_time)
	_aim_target = 1.0 if wants_aim else 0.0
	if intent.fire_mode_toggled:
		logic.toggle_fire_mode()
	if intent.reload and not swapping and not logic.start_reload() and logic.reload_block == &"no_magazine":
		_report_no_magazine()

	if intent.fire_pressed and logic.chambered == &"" and not logic.is_reloading and not logic.can_reload():
		_report_no_magazine()

	spread.update(definition, delta)
	var aiming: bool = aim_blend > 0.5
	current_spread_deg = spread.current_deg(definition, aiming, moving, crouched)

	var kick: Vector2 = Vector2.ZERO
	var shots: int = logic.update(delta, intent.fire and not swapping, intent.fire_pressed and not swapping) if _ballistics != null else 0
	if logic.is_reloading and not _was_reloading:
		_reload_voice = Audio.play_2d(definition.reload_empty_sound if logic.magazine == 0 else definition.reload_sound, &"Weapons")
		_reload_stream = _reload_voice.stream if _reload_voice != null else null
		var empty: bool = logic.reload_is_empty
		_play_anim(definition.anim_reload_empty if empty else definition.anim_reload,
				definition.reload_time_empty if empty else definition.reload_time)
	_was_reloading = logic.is_reloading
	for i: int in shots:
		last_shot_profile = _profile_for(logic.fired_ammo[i])
		var direction: Vector3 = WeaponSpread.random_direction(-aim.basis.z, current_spread_deg, _rng)
		var start: Array = _bullet_start(direction, shooter, aim)
		_ballistics.fire(start[0], start[1], definition, shooter, last_shot_profile)
		var shot_sound: StringName = definition.fire_sound_auto if logic.fire_mode == &"auto" and definition.fire_sound_auto != &"" else definition.fire_sound
		Audio.play_2d(shot_sound, &"Weapons", 0.0, _rng.randf_range(0.96, 1.04))
		spread.on_shot(definition)
		current_spread_deg = spread.current_deg(definition, aiming, moving, crouched)
		var recoil_scale: float = lerpf(1.0, definition.recoil_ads_mult, aim_blend)
		kick += Vector2(
			deg_to_rad(definition.recoil_pitch_deg),
			deg_to_rad(_rng.randf_range(-definition.recoil_yaw_deg, definition.recoil_yaw_deg))) * recoil_scale
		_kick = 1.0
		kick_viewmodel(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		_play_anim(definition.anim_fire, 0.0)
		_flash_remaining = FLASH_TIME_S
		_flash_particles.restart()
		_smoke_particles.restart()
		fired.emit(aim.origin, direction)
	return kick


## One shot's push on the gun's spring kick (ViewmodelRecoilRules); side and roll are random numbers in -1..1.
func kick_viewmodel(side: float, roll: float) -> void:
	var push: Array = ViewmodelRecoilRules.shot_velocity(definition, aim_blend, side, roll)
	_kick_position_velocity += push[0]
	_kick_rotation_velocity += push[1]


## Bullets leave the muzzle, aimed at the point the crosshair ray (camera, with spread) hits, so they land where
## the player aims. Returns [origin, direction]. Falls back to firing from the camera when there is no muzzle or
## it is blocked (gun pushed into a wall), where firing from the muzzle would shoot through the wall.
func _bullet_start(direction: Vector3, shooter: CollisionObject3D, aim: Transform3D) -> Array:
	if _muzzle == null or not _muzzle.is_inside_tree() or shooter == null:
		return [aim.origin, direction]
	var space: PhysicsDirectSpaceState3D = shooter.get_world_3d().direct_space_state
	var exclude: Array[RID] = [shooter.get_rid()]
	var muzzle_pos: Vector3 = _muzzle.global_position
	var blocked: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(aim.origin, muzzle_pos, MUZZLE_RAY_MASK, exclude))
	if not blocked.is_empty():
		return [aim.origin, direction]
	var far: Vector3 = aim.origin + direction * definition.max_range
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(aim.origin, far, MUZZLE_RAY_MASK, exclude))
	var target: Vector3 = hit["position"] if not hit.is_empty() else far
	var to_target: Vector3 = target - muzzle_pos
	# A target closer than the muzzle (or behind it) cannot be aimed at from there.
	if to_target.dot(direction) <= 0.0:
		return [aim.origin, direction]
	return [muzzle_pos, to_target.normalized()]


func _process(delta: float) -> void:
	var aim_spring: Array = AdsRules.spring_step(visual_aim, _visual_aim_velocity, _aim_target,
			AdsRules.spring_omega(definition.ads_time), AdsRules.spring_zeta(definition.ads_settle, _aim_target > 0.5), delta)
	visual_aim = aim_spring[0]
	_visual_aim_velocity = aim_spring[1]
	if _viewmodel == null or not is_visible_in_tree():
		return
	_kick = move_toward(_kick, 0.0, KICK_RECOVERY * delta)
	var spring: Array = ViewmodelRecoilRules.step(_kick_position, _kick_position_velocity, definition.recoil_spring_hz, definition.recoil_spring_damping, delta)
	_kick_position = spring[0]
	_kick_position_velocity = spring[1]
	spring = ViewmodelRecoilRules.step(_kick_rotation, _kick_rotation_velocity, definition.recoil_spring_hz, definition.recoil_spring_damping, delta)
	_kick_rotation = spring[0]
	_kick_rotation_velocity = spring[1]
	_draw_elapsed_s += delta
	_sway_position = WeaponSwayRules.approach(_sway_position,
		WeaponSwayRules.target_position(definition, _turn_rate, _strafe_speed, aim_blend), definition.sway_smoothing, delta)
	_sway_rotation_deg = WeaponSwayRules.approach(_sway_rotation_deg,
		WeaponSwayRules.target_rotation_deg(definition, _turn_rate, _strafe_speed, aim_blend), definition.sway_smoothing, delta)
	_bob_phase = WeaponSwayRules.advance_bob_phase(_bob_phase, _ground_speed, _stride_m, _grounded, delta)
	var bob_position: Vector3 = WeaponSwayRules.bob_position(definition, _bob_phase, _ground_speed, _grounded, aim_blend)
	var bob_rotation_deg: Vector3 = WeaponSwayRules.bob_rotation_deg(definition, _bob_phase, _ground_speed, _grounded, aim_blend)
	if _viewmodel.has_method(&"set_aim"):
		_viewmodel.call(&"set_aim", aim_blend, definition.scope_zoom)
	if _viewmodel.has_method(&"set_ads_steadiness"):
		_viewmodel.call(&"set_ads_steadiness", clampf(visual_aim, 0.0, 1.0), definition.ads_idle_steady, definition.ads_idle_speed)
	var rotation_deg: Vector3 = _sway_rotation_deg + bob_rotation_deg
	var sway_rotation: Vector3 = Vector3(deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y), deg_to_rad(rotation_deg.z))
	var base: Vector3 = definition.viewmodel_hip_position.lerp(definition.viewmodel_ads_position, visual_aim) \
		+ Vector3(0.0, -AdsRules.arc_offset_m(clampf(visual_aim, 0.0, 1.0), definition.ads_arc_m), 0.0) + _sway_position + bob_position
	var switch_offset: Vector3 = SWITCH_MOTION.lowered_offset * SwitchMotionRules.position_weight(_holster, _draw_elapsed_s, SWITCH_MOTION)
	var switch_rotation_deg: Vector3 = SWITCH_MOTION.lowered_rotation_deg * SwitchMotionRules.rotation_weight(_holster, _draw_elapsed_s, SWITCH_MOTION)
	if _anim != null:
		# The animations carry the reload; the spring kick and the hip turn go on top, about the grip. Drawing and
		# putting the weapon away have no clips, so the gun is lowered and tilted here.
		var aimed: float = visual_aim
		var turn: Vector3 = definition.viewmodel_hip_rotation_deg * (1.0 - aimed) + _kick_rotation + switch_rotation_deg
		_viewmodel.transform = Transform3D(Basis.from_euler(sway_rotation), base + _kick_position + switch_offset) \
				* ViewmodelRecoilRules.about_pivot(turn, definition.viewmodel_pivot)
	else:
		var reload_dip: float = sin(logic.reload_progress() * PI) * 0.12
		var swing: float = sin(clampf(_melee_t / _melee_swing_s(), 0.0, 1.0) * PI) if definition.melee else 0.0
		_viewmodel.position = base + Vector3(-0.10 * swing, -reload_dip + 0.03 * swing, _kick * KICK_DISTANCE - 0.28 * swing) + switch_offset
		_viewmodel.rotation = Vector3(-reload_dip * 2.0 + 0.25 * swing, 0.6 * swing, 0.0) + sway_rotation + switch_rotation_deg * (PI / 180.0)
	_flash_remaining -= delta
	_flash.visible = _flash_remaining > 0.0


## One blade swing: the strike lands part-way through. The fire button swings quickly, the aim button
## makes a slower, longer heavy attack.
func _melee_update(intent: InputIntent, delta: float, shooter: CollisionObject3D, aim: Transform3D) -> Vector2:
	aim_blend = move_toward(aim_blend, 0.0, delta / definition.ads_time)
	_aim_target = 0.0
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
	FpsArms.attach(_viewmodel, FPS_ARMS)
	for node: Node in _viewmodel.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.5)
	_flash.omni_range = 2.5
	_flash.visible = false
	var muzzle: Node3D = _viewmodel.get_node_or_null(^"Muzzle") as Node3D
	_muzzle = muzzle if muzzle != null else _viewmodel
	_muzzle.add_child(_flash)
	_flash_particles = MUZZLE_FLASH.instantiate() as GPUParticles3D
	_flash_quad_size = (_flash_particles.draw_pass_1 as QuadMesh).size
	_muzzle.add_child(_flash_particles)
	_smoke_particles = MUZZLE_SMOKE.instantiate() as GPUParticles3D
	_smoke_quad_size = (_smoke_particles.draw_pass_1 as QuadMesh).size
	_muzzle.add_child(_smoke_particles)
	_apply_muzzle_effects()
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


## Flash light, flash sprite and smoke sizes from the definition; the suppressed version is dimmer and smaller.
func _apply_muzzle_effects() -> void:
	if _flash == null:
		return
	var flash_scale: float = definition.muzzle_flash_scale * (0.4 if definition.suppressed else 1.0)
	_flash.light_energy = definition.muzzle_light_energy * (0.24 if definition.suppressed else 1.0)
	_flash.omni_range = 2.5 * clampf(flash_scale, 0.2, 1.0)
	# The flash sprite is a billboard that ignores the node's scale, so the quad itself is resized (a copy per
	# weapon: the scene's mesh is shared by every instance).
	_resize_quad(_flash_particles, _flash_quad_size, flash_scale)
	_resize_quad(_smoke_particles, _smoke_quad_size, definition.muzzle_smoke_scale)
	_smoke_particles.amount_ratio = clampf(definition.muzzle_smoke_scale, 0.2, 1.0)


func _resize_quad(particles: GPUParticles3D, base_size: Vector2, factor: float) -> void:
	var quad: QuadMesh = particles.draw_pass_1.duplicate() as QuadMesh
	quad.size = base_size * factor
	particles.draw_pass_1 = quad


## The click of a gun with nothing in it and nothing to reload it with.
func _report_no_magazine() -> void:
	Audio.play_2d(definition.dry_fire_sound, &"Weapons")
	EventBus.reload_blocked.emit(&"no_magazine")


func _profile_for(ammo_id: StringName) -> ShotProfile:
	return ShotProfile.from_ammo(InventoryCatalog.default().find_ammo(ammo_id))
