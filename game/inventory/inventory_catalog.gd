class_name InventoryCatalog
extends Resource
## Every ammo and magazine type, looked up by id (saves store ids, not resources).

const DEFAULT_PATH: String = "res://data/inventory/catalog.tres"

static var _default: InventoryCatalog

@export var ammo: Array[AmmoType] = []
@export var magazines: Array[MagazineType] = []


static func default() -> InventoryCatalog:
	if _default == null:
		_default = load(DEFAULT_PATH) as InventoryCatalog
	return _default


func find_ammo(id: StringName) -> AmmoType:
	for entry: AmmoType in ammo:
		if entry.id == id:
			return entry
	return null


func find_magazine(id: StringName) -> MagazineType:
	for entry: MagazineType in magazines:
		if entry.id == id:
			return entry
	return null
