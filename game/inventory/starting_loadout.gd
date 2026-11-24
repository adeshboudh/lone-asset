class_name StartingLoadout
extends Resource
## What the player carries at the start of a mission (data/inventory/starting_loadout.tres).

@export var pouch_count: int = 8
@export var backpack_count: int = 12
@export var magazines: Array[StartingMagazine] = []
## Ammo id to loose rounds.
@export var loose_ammo: Dictionary = {}


func build() -> AmmoInventory:
	var inventory: AmmoInventory = AmmoInventory.new(pouch_count, backpack_count)
	for entry: StartingMagazine in magazines:
		var magazine: Magazine = Magazine.new(entry.type)
		for i: int in mini(entry.rounds, entry.type.capacity):
			magazine.rounds.append(entry.ammo.id)
		inventory.add_magazine(magazine)
	for id: Variant in loose_ammo:
		inventory.add_loose(StringName(String(id)), int(loose_ammo[id]))
	return inventory
