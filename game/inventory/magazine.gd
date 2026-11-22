class_name Magazine
extends RefCounted
## A magazine and the rounds in it. rounds holds ammo ids; the last one is the top round and fires first.

var type: MagazineType
var rounds: Array[StringName] = []


func _init(magazine_type: MagazineType, loaded: Array = []) -> void:
	type = magazine_type
	for id: Variant in loaded:
		rounds.append(StringName(id))


## A magazine filled to capacity with one ammo type.
static func full_of(magazine_type: MagazineType, ammo: AmmoType) -> Magazine:
	var magazine: Magazine = Magazine.new(magazine_type)
	for i: int in magazine_type.capacity:
		magazine.rounds.append(ammo.id)
	return magazine


func count() -> int:
	return rounds.size()


func is_empty() -> bool:
	return rounds.is_empty()


func is_full() -> bool:
	return rounds.size() >= type.capacity


## The round that fires next, or an empty id.
func top() -> StringName:
	return rounds.back() if not rounds.is_empty() else &""


func to_dict() -> Dictionary:
	return {"type": String(type.id), "rounds": rounds.map(func(id: StringName) -> String: return String(id))}


## null when the data is missing or names an unknown type.
static func from_dict(data: Variant, catalog: InventoryCatalog) -> Magazine:
	if not data is Dictionary:
		return null
	var magazine_type: MagazineType = catalog.find_magazine(StringName(String((data as Dictionary).get("type", ""))))
	if magazine_type == null:
		return null
	var loaded: Array = (data as Dictionary).get("rounds", [])
	return Magazine.new(magazine_type, loaded.slice(0, magazine_type.capacity))
