class_name WeaponLogic
extends RefCounted
## Ammo, fire timing, fire modes and reloading (design §5.2). Pure logic: the Weapon node feeds it
## input and time, so it is unit-tested at any tick rate.

var definition: WeaponDefinition
## The player's pouches. null means unlimited magazines (guards): a reload makes a fresh full one.
var inventory: AmmoInventory
## The magazine in the gun, or null.
var inserted: Magazine
## Ammo id of the round in the chamber, empty when there is none.
var chambered: StringName = &""
var is_reloading: bool = false
## Ammo ids of the rounds fired in the last update(), one per shot.
var fired_ammo: Array[StringName] = []
## Why the last start_reload() failed: &"full" or &"no_magazine".
var reload_block: StringName = &""
## True while the running reload is an empty one (nothing was chambered when it began).
var reload_is_empty: bool = false
var fire_mode: StringName:
	get:
		return definition.fire_modes[_fire_mode_index]
## Rounds in the gun: the magazine plus the chambered round.
var magazine: int:
	get:
		return (inserted.count() if inserted != null else 0) + (1 if chambered != &"" else 0)

var _fire_mode_index: int = 0
var _reload_remaining: float = 0.0
## The magazine the running reload swaps in and where it came from (-1: made on the spot, unlimited magazines).
var _reload_magazine: Magazine
var _reload_pouch: int = -1
## Time until the next round can fire. Goes negative within a tick so the fire rate stays exact.
var _cooldown: float = 0.0


func _init(weapon: WeaponDefinition, pouches: AmmoInventory = null) -> void:
	definition = weapon
	inventory = pouches
	# A loaded gun: a full magazine and one more round in the chamber.
	inserted = Magazine.full_of(weapon.default_magazine, weapon.default_ammo)
	chambered = weapon.default_ammo.id


## Advances time and returns how many rounds were fired this tick.
## trigger_pressed is true only on the tick the trigger went down.
func update(delta: float, trigger_down: bool, trigger_pressed: bool) -> int:
	_cooldown -= delta
	fired_ammo.clear()
	if is_reloading:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_finish_reload()
		_cooldown = maxf(_cooldown, 0.0)
		return 0

	if trigger_pressed and chambered == &"":
		start_reload()
		return 0

	var interval: float = 60.0 / definition.fire_rate_rpm
	var shots: int = 0
	if fire_mode == &"auto":
		if trigger_down:
			while _cooldown <= 0.0 and chambered != &"":
				_fire_one()
				shots += 1
				_cooldown += interval
	elif trigger_pressed and _cooldown <= 0.0 and chambered != &"":
		_fire_one()
		shots = 1
		_cooldown = maxf(_cooldown, 0.0) + interval

	# No banking time while the trigger is up or the gun is dry.
	if not trigger_down or chambered == &"":
		_cooldown = maxf(_cooldown, 0.0)
	return shots


## True when a reload could start now: nothing is running and a spare magazine holds more rounds than the one in the
## gun (or the gun has no limit).
func can_reload() -> bool:
	return not is_reloading and _find_reload_magazine().get("ok", false)


## Starts a reload. False (and reload_block says why) when one is running, the gun is full, or no magazine fits.
func start_reload() -> bool:
	if is_reloading:
		reload_block = &""
		return false
	if inserted != null and inserted.is_full() and chambered != &"":
		reload_block = &"full"
		return false
	var found: Dictionary = _find_reload_magazine()
	if not found.get("ok", false):
		reload_block = &"no_magazine"
		return false
	reload_block = &""
	_reload_magazine = found["magazine"]
	_reload_pouch = found["pouch"]
	reload_is_empty = chambered == &""
	is_reloading = true
	_reload_remaining = definition.reload_time_empty if reload_is_empty else definition.reload_time
	return true


## Stops a reload that is under way: no magazine moves, the gun keeps the one it has.
func cancel_reload() -> void:
	is_reloading = false
	_reload_remaining = 0.0
	_reload_magazine = null
	_reload_pouch = -1


## Switches to another version of the same weapon (attachment swap); the magazine and chamber carry over.
func swap_definition(weapon: WeaponDefinition) -> void:
	definition = weapon
	_fire_mode_index = mini(_fire_mode_index, weapon.fire_modes.size() - 1)


func toggle_fire_mode() -> void:
	if not is_reloading:
		_fire_mode_index = (_fire_mode_index + 1) % definition.fire_modes.size()


## 0 → 1 progress of the current reload.
func reload_progress() -> float:
	if not is_reloading:
		return 0.0
	var total: float = definition.reload_time_empty if reload_is_empty else definition.reload_time
	return clampf(1.0 - _reload_remaining / total, 0.0, 1.0)


## Sets how many rounds are in the gun (tests and old saves): one chambered, the rest in the magazine, of the ammo
## already in the gun (or the weapon's default).
func set_round_count(count: int) -> void:
	var ammo_id: StringName = chambered if chambered != &"" else (inserted.top() if inserted != null and not inserted.is_empty() else definition.default_ammo.id)
	var magazine_type: MagazineType = inserted.type if inserted != null else definition.default_magazine
	inserted = Magazine.new(magazine_type)
	chambered = &""
	var remaining: int = clampi(count, 0, magazine_type.capacity + 1)
	if remaining > 0:
		chambered = ammo_id
		remaining -= 1
	for i: int in remaining:
		inserted.rounds.append(ammo_id)


func to_dict() -> Dictionary:
	return {"chambered": String(chambered), "magazine": inserted.to_dict() if inserted != null else null}


func load_dict(data: Dictionary, catalog: InventoryCatalog) -> void:
	chambered = StringName(String(data.get("chambered", "")))
	inserted = Magazine.from_dict(data.get("magazine"), catalog)


func _fire_one() -> void:
	fired_ammo.append(chambered)
	chambered = &""
	_chamber_next()


## Chambers the next round from the magazine when the chamber is empty.
func _chamber_next() -> void:
	if chambered == &"" and inserted != null and not inserted.is_empty():
		chambered = inserted.rounds.pop_back()


## The magazine a reload takes: {"ok", "magazine", "pouch"}.
func _find_reload_magazine() -> Dictionary:
	var in_gun: int = inserted.count() if inserted != null else 0
	if inventory == null:
		# Unlimited magazines (guards): a fresh full one, unless the gun is already full.
		if inserted != null and inserted.is_full() and chambered != &"":
			return {"ok": false}
		return {"ok": true, "magazine": Magazine.full_of(definition.default_magazine, definition.default_ammo), "pouch": -1}
	var current: StringName = chambered if chambered != &"" else (inserted.top() if inserted != null else &"")
	var index: int = MagazineRules.best_magazine(inventory.pouches, definition, current, in_gun)
	if index < 0:
		return {"ok": false}
	return {"ok": true, "magazine": inventory.pouches[index], "pouch": index}


func _finish_reload() -> void:
	is_reloading = false
	var fresh: Magazine = _reload_magazine
	var previous: Magazine = inserted
	if inventory != null:
		# The pouches may have changed while the animation ran (the inventory is real-time): the magazine must still be there.
		var index: int = inventory.pouches.find(fresh)
		if index < 0:
			_reload_magazine = null
			return
		if previous != null:
			inventory.pouches[index] = previous
		else:
			inventory.pouches.remove_at(index)
	inserted = fresh
	_reload_magazine = null
	_reload_pouch = -1
	_chamber_next()
