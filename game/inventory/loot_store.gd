class_name LootStore
extends LooseAmmoStore
## The contents of an external container (crate, locker, shelf, fallen guard): magazines, loose rounds and items
## (id to count). Same shape as the player's backpack so the same moves work between them.

var magazines: Array[Magazine] = []
## Item id to count (medical and utility items).
var items: Dictionary = {}
var capacity: int


func _init(magazine_capacity: int = 12) -> void:
	capacity = magazine_capacity


## False when the container holds as many magazines as it can.
func add_magazine(magazine: Magazine) -> bool:
	if magazines.size() >= capacity:
		return false
	magazines.append(magazine)
	return true


func is_empty() -> bool:
	return magazines.is_empty() and loose.is_empty() and items.is_empty()


func to_dict() -> Dictionary:
	var loose_data: Dictionary = {}
	for id: StringName in loose:
		loose_data[String(id)] = int(loose[id])
	return {
		"capacity": capacity,
		"magazines": magazines.map(func(magazine: Magazine) -> Dictionary: return magazine.to_dict()),
		"loose": loose_data,
		"items": items.duplicate(),
	}


static func from_dict(data: Dictionary, catalog: InventoryCatalog) -> LootStore:
	var store: LootStore = LootStore.new(int(data.get("capacity", 12)))
	for saved: Variant in data.get("magazines", []):
		var magazine: Magazine = Magazine.from_dict(saved, catalog)
		if magazine != null:
			store.add_magazine(magazine)
	var saved_loose: Dictionary = data.get("loose", {})
	for id: Variant in saved_loose:
		store.add_loose(StringName(String(id)), int(saved_loose[id]))
	var saved_items: Dictionary = data.get("items", {})
	for id: Variant in saved_items:
		store.items[String(id)] = int(saved_items[id])
	return store
