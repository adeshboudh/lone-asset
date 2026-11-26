class_name AmmoInventory
extends LooseAmmoStore
## The player's tactical rig and backpack. `pouches` is the rig: a fixed number of slots, and the only magazines the
## reload key uses. `backpack` holds spare magazines (moved into the rig in the inventory screen) and `loose` is its
## loose ammo. Saved with the checkpoint.

var pouch_count: int
var pouches: Array[Magazine] = []
var backpack_capacity: int
var backpack: Array[Magazine] = []
# `loose` (from LooseAmmoStore) is the backpack's loose ammo.


func _init(slots: int = 6, backpack_slots: int = 12) -> void:
	pouch_count = slots
	backpack_capacity = backpack_slots


## False when every pouch is taken.
func add_magazine(magazine: Magazine) -> bool:
	if pouches.size() >= pouch_count:
		return false
	pouches.append(magazine)
	return true


## Backpack slots in use: one per magazine and one per started stack of loose ammo (AmmoType.stack_size).
func slots_used() -> int:
	var used: int = backpack.size()
	for id: StringName in loose:
		used += _stacks(id, loose_count(id))
	return used


func free_slots() -> int:
	return maxi(backpack_capacity - slots_used(), 0)


## False when the backpack has no free slot.
func add_to_backpack(magazine: Magazine) -> bool:
	if free_slots() < 1:
		return false
	backpack.append(magazine)
	return true


## Loose ammo takes backpack slots: only what fits is accepted, the number accepted is returned.
func add_loose(ammo_id: StringName, count: int) -> int:
	return super(ammo_id, mini(count, loose_room(ammo_id)))


func loose_room(ammo_id: StringName) -> int:
	var stack: int = _stack_size(ammo_id)
	var in_last_stack: int = loose_count(ammo_id) % stack
	var rest_of_stack: int = (stack - in_last_stack) % stack
	return rest_of_stack + free_slots() * stack


## The number of slots `count` rounds use.
func _stacks(ammo_id: StringName, count: int) -> int:
	return ceili(float(count) / float(_stack_size(ammo_id)))


func _stack_size(ammo_id: StringName) -> int:
	var ammo: AmmoType = InventoryCatalog.default().find_ammo(ammo_id)
	return maxi(ammo.stack_size if ammo != null else 60, 1)


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
		"backpack_capacity": backpack_capacity,
		"backpack": backpack.map(func(magazine: Magazine) -> Dictionary: return magazine.to_dict()),
		"loose": loose_data,
	}


static func from_dict(data: Dictionary, catalog: InventoryCatalog) -> AmmoInventory:
	var inventory: AmmoInventory = AmmoInventory.new(int(data.get("pouch_count", 6)), int(data.get("backpack_capacity", 12)))
	for saved: Variant in data.get("pouches", []):
		var magazine: Magazine = Magazine.from_dict(saved, catalog)
		if magazine != null:
			inventory.add_magazine(magazine)
	for saved: Variant in data.get("backpack", []):
		var magazine: Magazine = Magazine.from_dict(saved, catalog)
		if magazine != null:
			inventory.add_to_backpack(magazine)
	var saved_loose: Dictionary = data.get("loose", {})
	for id: Variant in saved_loose:
		# A saved game is taken as it was, even if it holds more than the slots allow.
		inventory.loose[StringName(String(id))] = int(saved_loose[id])
	return inventory
