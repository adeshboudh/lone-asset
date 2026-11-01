class_name GuardWeapon
extends Node
## A guard's rifle (design §7.1). Fires through the level's BallisticsSystem like the player's weapon,
## so cover stops its bullets, and makes the same kind of gameplay noise and sound.

signal fired(origin: Vector3, direction: Vector3)

var logic: WeaponLogic

var _guard: Guard
var _ballistics: BallisticsSystem
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_guard = get_parent() as Guard
	logic = WeaponLogic.new(_guard.profile.weapon)
	_rng.randomize()


## Where bullets leave the weapon.
func muzzle_position() -> Vector3:
	return _guard.eye_position() + _guard.facing() * 0.5 + Vector3.DOWN * 0.25


## Time passing with the trigger held or not. Returns how many rounds were fired this tick.
## `error_deg` is the aim error (cone half-angle) around the direction to `target_point`.
func update(delta: float, trigger_down: bool, target_point: Vector3, error_deg: float) -> int:
	if _ballistics == null:
		_ballistics = get_tree().get_first_node_in_group(BallisticsSystem.GROUP) as BallisticsSystem
	if trigger_down and logic.magazine == 0:
		logic.start_reload()
	var shots: int = logic.update(delta, trigger_down, false) if _ballistics != null else 0
	var weapon: WeaponDefinition = _guard.profile.weapon
	for i: int in shots:
		var origin: Vector3 = muzzle_position()
		var aim: Vector3 = (target_point - origin).normalized()
		var direction: Vector3 = WeaponSpread.random_direction(aim, error_deg, _rng)
		_ballistics.fire(origin, direction, weapon, _guard)
		NoiseSystem.emit_noise(NoiseEvent.SHOT_SUPPRESSED if weapon.suppressed else NoiseEvent.SHOT, origin, weapon.noise_radius_m, _guard)
		Audio.play_3d(weapon.fire_sound, origin, &"Weapons", 0.0, _guard)
		fired.emit(origin, direction)
	return shots
