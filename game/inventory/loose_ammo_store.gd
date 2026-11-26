class_name LooseAmmoStore
extends RefCounted
## Something that holds loose rounds (ammo id to count) and can pack them into magazines and strip them out again:
## the player's backpack (AmmoInventory) and an external container (LootStore). MagazineOperation works on this.

## Ammo id to number of loose rounds.
var loose: Dictionary = {}


func loose_count(ammo_id: StringName) -> int:
	return int(loose.get(ammo_id, 0))


## Adds rounds and returns how many were accepted (all of them here; a store with limited room accepts fewer).
func add_loose(ammo_id: StringName, count: int) -> int:
	if count <= 0:
		return 0
	loose[ammo_id] = loose_count(ammo_id) + count
	return count


## How many more rounds of this ammo the store can take.
func loose_room(_ammo_id: StringName) -> int:
	return 1 << 30


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


## Moves the top round of a magazine back to loose ammo. False when the magazine is empty or there is no room.
func unload_one(magazine: Magazine) -> bool:
	if magazine.is_empty() or loose_room(magazine.top()) < 1:
		return false
	add_loose(MagazineRules.unload_round(magazine), 1)
	return true
