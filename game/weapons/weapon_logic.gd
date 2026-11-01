class_name WeaponLogic
extends RefCounted
## Ammo, fire timing, fire modes and reloading (design §5.2). Pure logic: the Weapon node feeds it
## input and time, so it is unit-tested at any tick rate.

var definition: WeaponDefinition
var magazine: int
var reserve: int
var is_reloading: bool = false
var fire_mode: StringName:
	get:
		return definition.fire_modes[_fire_mode_index]

var _fire_mode_index: int = 0
var _reload_remaining: float = 0.0
## Time until the next round can fire. Goes negative within a tick so the fire rate stays exact.
var _cooldown: float = 0.0


func _init(weapon: WeaponDefinition) -> void:
	definition = weapon
	magazine = weapon.magazine_size
	reserve = weapon.reserve_ammo


## Advances time and returns how many rounds were fired this tick.
## trigger_pressed is true only on the tick the trigger went down.
func update(delta: float, trigger_down: bool, trigger_pressed: bool) -> int:
	_cooldown -= delta
	if is_reloading:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_finish_reload()
		_cooldown = maxf(_cooldown, 0.0)
		return 0

	if trigger_pressed and magazine == 0:
		start_reload()
		return 0

	var interval: float = 60.0 / definition.fire_rate_rpm
	var shots: int = 0
	if fire_mode == &"auto":
		if trigger_down:
			while _cooldown <= 0.0 and magazine > 0:
				magazine -= 1
				shots += 1
				_cooldown += interval
	elif trigger_pressed and _cooldown <= 0.0 and magazine > 0:
		magazine -= 1
		shots = 1
		_cooldown = maxf(_cooldown, 0.0) + interval

	# No banking time while the trigger is up or the magazine is empty.
	if not trigger_down or magazine == 0:
		_cooldown = maxf(_cooldown, 0.0)
	return shots


## Returns false if a reload is not possible (already reloading, magazine full or no reserve).
func start_reload() -> bool:
	if is_reloading or magazine >= definition.magazine_size or reserve <= 0:
		return false
	is_reloading = true
	_reload_remaining = definition.reload_time_empty if magazine == 0 else definition.reload_time
	return true


func toggle_fire_mode() -> void:
	if not is_reloading:
		_fire_mode_index = (_fire_mode_index + 1) % definition.fire_modes.size()


## 0 → 1 progress of the current reload.
func reload_progress() -> float:
	if not is_reloading:
		return 0.0
	var total: float = definition.reload_time_empty if magazine == 0 else definition.reload_time
	return clampf(1.0 - _reload_remaining / total, 0.0, 1.0)


func _finish_reload() -> void:
	var taken: int = mini(definition.magazine_size - magazine, reserve)
	magazine += taken
	reserve -= taken
	is_reloading = false
