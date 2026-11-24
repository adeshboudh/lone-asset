class_name InventoryMoves
extends RefCounted
## Pure rules for dragging items in the inventory screen: whether a drop is allowed and what it does. The screen's
## slots only ask this class and apply the result. Every function returns {"ok": bool, "reason": StringName}; the
## reason is empty when ok, otherwise one of &"full", &"wrong_fit", &"move_to_rig", &"same_slot", &"empty".

enum Place { RIG, BACKPACK, CONTAINER, GUN }

const REASON_TEXT: Dictionary = {
	&"full": "NO ROOM THERE",
	&"wrong_fit": "DOES NOT FIT",
	&"move_to_rig": "MOVE IT TO THE RIG FIRST",
	&"same_slot": "",
	&"empty": "NOTHING THERE",
}


static func _result(ok: bool, reason: StringName = &"") -> Dictionary:
	return {"ok": ok, "reason": reason}


## The magazines held at a place (null for the gun, which holds none of this list).
static func _list(inventory: AmmoInventory, store: LootStore, place: Place) -> Array[Magazine]:
	match place:
		Place.RIG:
			return inventory.pouches
		Place.BACKPACK:
			return inventory.backpack
		Place.CONTAINER:
			return store.magazines if store != null else ([] as Array[Magazine])
	return [] as Array[Magazine]


static func _capacity(inventory: AmmoInventory, store: LootStore, place: Place) -> int:
	match place:
		Place.RIG:
			return inventory.pouch_count
		Place.BACKPACK:
			return inventory.backpack_capacity
		Place.CONTAINER:
			return store.capacity if store != null else 0
	return 0


## Whether the magazine could move; nothing changes.
static func can_move_magazine(inventory: AmmoInventory, store: LootStore, from_place: Place, from_index: int, to_place: Place) -> Dictionary:
	if from_place == Place.GUN or to_place == Place.GUN:
		return _result(false, &"wrong_fit")
	var source: Array[Magazine] = _list(inventory, store, from_place)
	if from_index < 0 or from_index >= source.size():
		return _result(false, &"empty")
	if from_place == to_place:
		return _result(false, &"same_slot")
	if to_place == Place.BACKPACK:
		if inventory.free_slots() < 1:
			return _result(false, &"full")
	elif _list(inventory, store, to_place).size() >= _capacity(inventory, store, to_place):
		return _result(false, &"full")
	return _result(true)


## Moves a magazine to the end of another place's list. Nothing changes unless the result is ok.
static func move_magazine(inventory: AmmoInventory, store: LootStore, from_place: Place, from_index: int, to_place: Place) -> Dictionary:
	var check: Dictionary = can_move_magazine(inventory, store, from_place, from_index, to_place)
	if check["ok"]:
		var source: Array[Magazine] = _list(inventory, store, from_place)
		_list(inventory, store, to_place).append(source[from_index])
		source.remove_at(from_index)
	return check


## Only magazines in the rig go into a gun: it is the same as the reload key.
static func can_reload_from(from_place: Place) -> Dictionary:
	if from_place == Place.RIG:
		return _result(true)
	return _result(false, &"move_to_rig")


## How many of `count` loose rounds could move to `to_place` (the backpack takes only what fits its slots).
static func loose_movable(inventory: AmmoInventory, store: LootStore, ammo_id: StringName, count: int, to_place: Place) -> int:
	if store == null:
		return 0
	if to_place == Place.CONTAINER:
		return mini(count, inventory.loose_count(ammo_id))
	if to_place == Place.BACKPACK:
		return mini(mini(count, store.loose_count(ammo_id)), inventory.loose_room(ammo_id))
	return 0


## Whether loose rounds could move to `to_place`; nothing changes.
static func can_move_loose(inventory: AmmoInventory, store: LootStore, ammo_id: StringName, to_place: Place, count: int = 1 << 30) -> Dictionary:
	if store == null or (to_place != Place.BACKPACK and to_place != Place.CONTAINER):
		return _result(false, &"wrong_fit")
	if loose_movable(inventory, store, ammo_id, count, to_place) > 0:
		return _result(true)
	var source: LooseAmmoStore = inventory if to_place == Place.CONTAINER else store
	return _result(false, &"empty" if source.loose_count(ammo_id) < 1 else &"full")


## Moves up to `count` loose rounds between the backpack and a container (to_place BACKPACK or CONTAINER).
static func move_loose(inventory: AmmoInventory, store: LootStore, ammo_id: StringName, count: int, to_place: Place) -> Dictionary:
	var check: Dictionary = can_move_loose(inventory, store, ammo_id, to_place, count)
	if not check["ok"]:
		return check
	var amount: int = loose_movable(inventory, store, ammo_id, count, to_place)
	if to_place == Place.CONTAINER:
		store.add_loose(ammo_id, inventory.take_loose(ammo_id, amount))
	else:
		inventory.add_loose(ammo_id, store.take_loose(ammo_id, amount))
	return check


## Loose rounds onto a magazine: the caliber must fit and there must be room.
static func can_pack(magazine: Magazine, ammo: AmmoType) -> Dictionary:
	if magazine.is_full():
		return _result(false, &"full")
	if not MagazineRules.can_load(magazine, ammo):
		return _result(false, &"wrong_fit")
	return _result(true)


## The text of a refusal for the toast, empty when nothing should be shown.
static func reason_text(reason: StringName) -> String:
	return String(REASON_TEXT.get(reason, ""))
