class_name AmmoInventory
extends RefCounted
## The player's magazine pouches (a fixed number of slots) and loose ammo. Saved with the checkpoint.

var pouch_count: int
var pouches: Array[Magazine] = []
## Ammo id to number of loose rounds.
var loose: Dictionary = {}


func _init(slots: int = 6) -> void:
	pouch_count = slots


## False when every pouch is taken.
func add_magazine(magazine: Magazine) -> bool:
	if pouches.size() >= pouch_count:
		return false
	pouches.append(magazine)
	return true


func loose_count(ammo_id: StringName) -> int:
	return int(loose.get(ammo_id, 0))


func add_loose(ammo_id: StringName, count: int) -> void:
	if count > 0:
		loose[ammo_id] = loose_count(ammo_id) + count


## Takes up to `count` loose rounds; returns how many were taken.
func take_loose(ammo_id: StringName, count: int) -> int:
	var taken: int = mini(count, loose_count(ammo_id))
	if taken <= 0:
		return 0
	loose[ammo_id] = loose_count(ammo_id) - taken
	if int(loose[ammo_id]) == 0:
		loose.erase(ammo_id)
	return taken


## Moves one loose round into a magazine. False when none is loose or the magazine will not take it.
func fill_one(magazine: Magazine, ammo: AmmoType) -> bool:
	if loose_count(ammo.id) < 1 or not MagazineRules.can_load(magazine, ammo):
		return false
	take_loose(ammo.id, 1)
	return MagazineRules.load_round(magazine, ammo)


## Moves the top round of a magazine back to loose ammo. False when the magazine is empty.
func unload_one(magazine: Magazine) -> bool:
	var id: StringName = MagazineRules.unload_round(magazine)
	if id == &"":
		return false
	add_loose(id, 1)
	return true


## How many non-empty magazines in the pouches the weapon takes (the HUD's spare magazine count).
func spare_magazines_for(weapon: WeaponDefinition) -> int:
	var spare: int = 0
	for magazine: Magazine in pouches:
		if not magazine.is_empty() and MagazineRules.can_insert(weapon, magazine):
			spare += 1
	return spare


## Old saves counted a reserve of plain rounds: they become full spare magazines of the weapon's default type while
## pouches are free, the rest loose ammo.
func stock_reserve(weapon: WeaponDefinition, rounds: int) -> void:
	var remaining: int = rounds
	while remaining > 0 and pouches.size() < pouch_count:
		var count: int = mini(remaining, weapon.default_magazine.capacity)
		var magazine: Magazine = Magazine.new(weapon.default_magazine)
		for i: int in count:
			magazine.rounds.append(weapon.default_ammo.id)
		pouches.append(magazine)
		remaining -= count
	add_loose(weapon.default_ammo.id, remaining)


func to_dict() -> Dictionary:
	var loose_data: Dictionary = {}
	for id: StringName in loose:
		loose_data[String(id)] = int(loose[id])
	return {
		"pouch_count": pouch_count,
		"pouches": pouches.map(func(magazine: Magazine) -> Dictionary: return magazine.to_dict()),
		"loose": loose_data,
	}


static func from_dict(data: Dictionary, catalog: InventoryCatalog) -> AmmoInventory:
	var inventory: AmmoInventory = AmmoInventory.new(int(data.get("pouch_count", 6)))
	for saved: Variant in data.get("pouches", []):
		var magazine: Magazine = Magazine.from_dict(saved, catalog)
		if magazine != null:
			inventory.add_magazine(magazine)
	var saved_loose: Dictionary = data.get("loose", {})
	for id: Variant in saved_loose:
		inventory.add_loose(StringName(String(id)), int(saved_loose[id]))
	return inventory
