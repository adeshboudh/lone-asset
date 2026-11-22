class_name MagazineOperation
extends RefCounted
## Filling or unloading one magazine in the inventory screen, round by round in real time. Pure: the screen feeds it
## time and plays the sounds. A round moves when its time has run out, so stopping loses at most the round in progress
## (which was never moved).

enum Kind { FILL, UNLOAD }

var kind: Kind
var magazine: Magazine
## The ammo being loaded (FILL only).
var ammo: AmmoType

var _progress_s: float = 0.0


func _init(operation_kind: Kind, target: Magazine, load_ammo: AmmoType = null) -> void:
	kind = operation_kind
	magazine = target
	ammo = load_ammo


## 0..1 progress of the round being moved.
func fraction(settings: InventorySettings) -> float:
	return clampf(_progress_s / _time_per_round(settings), 0.0, 1.0)


## Advances time; returns how many rounds moved (0 or more).
func advance(delta: float, inventory: AmmoInventory, settings: InventorySettings) -> int:
	var moved: int = 0
	_progress_s += delta
	var per_round: float = _time_per_round(settings)
	while _progress_s >= per_round and not is_finished(inventory):
		_progress_s -= per_round
		var done: bool = inventory.fill_one(magazine, ammo) if kind == Kind.FILL else inventory.unload_one(magazine)
		if not done:
			break
		moved += 1
	if is_finished(inventory):
		_progress_s = 0.0
	return moved


## Nothing more can be moved: the magazine is full or out of loose ammo (FILL), or empty (UNLOAD).
func is_finished(inventory: AmmoInventory) -> bool:
	if kind == Kind.FILL:
		return not MagazineRules.can_load(magazine, ammo) or inventory.loose_count(ammo.id) < 1
	return magazine.is_empty()


func _time_per_round(settings: InventorySettings) -> float:
	return settings.fill_time_per_round_s if kind == Kind.FILL else settings.unload_time_per_round_s
