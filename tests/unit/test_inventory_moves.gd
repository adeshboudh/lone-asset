extends GdUnitTestSuite
## Drag and drop rules between rig, backpack, container and guns.

const STANAG: MagazineType = preload("res://data/magazines/stanag_30.tres")
const GLOCK_17: MagazineType = preload("res://data/magazines/glock_17rd.tres")
const FMJ: AmmoType = preload("res://data/ammo/fmj_556.tres")
const NINE: AmmoType = preload("res://data/ammo/fmj_9.tres")

var _inventory: AmmoInventory
var _store: LootStore


func before_test() -> void:
	_inventory = AmmoInventory.new(2, 2)
	_store = LootStore.new(2)


func _rounds_total() -> int:
	var total: int = 0
	for list: Array in [_inventory.pouches, _inventory.backpack, _store.magazines]:
		for magazine: Magazine in list:
			total += magazine.count()
	for id: StringName in _inventory.loose:
		total += _inventory.loose_count(id)
	for id: StringName in _store.loose:
		total += _store.loose_count(id)
	return total


func test_rig_magazine_moves_to_the_backpack_and_back() -> void:
	var magazine: Magazine = Magazine.full_of(STANAG, FMJ)
	_inventory.add_magazine(magazine)
	var result: Dictionary = InventoryMoves.move_magazine(_inventory, _store, InventoryMoves.Place.RIG, 0, InventoryMoves.Place.BACKPACK)
	assert_bool(result["ok"]).is_true()
	assert_int(_inventory.pouches.size()).is_equal(0)
	assert_object(_inventory.backpack[0]).is_same(magazine)
	result = InventoryMoves.move_magazine(_inventory, _store, InventoryMoves.Place.BACKPACK, 0, InventoryMoves.Place.RIG)
	assert_bool(result["ok"]).is_true()
	assert_object(_inventory.pouches[0]).is_same(magazine)


func test_container_magazine_moves_to_the_backpack() -> void:
	_store.add_magazine(Magazine.full_of(STANAG, FMJ))
	var result: Dictionary = InventoryMoves.move_magazine(_inventory, _store, InventoryMoves.Place.CONTAINER, 0, InventoryMoves.Place.BACKPACK)
	assert_bool(result["ok"]).is_true()
	assert_int(_store.magazines.size()).is_equal(0)
	assert_int(_inventory.backpack.size()).is_equal(1)


func test_a_full_destination_changes_nothing() -> void:
	_inventory.add_to_backpack(Magazine.new(STANAG))
	_inventory.add_to_backpack(Magazine.new(STANAG))
	_inventory.add_magazine(Magazine.full_of(STANAG, FMJ))
	var before: int = _rounds_total()
	var result: Dictionary = InventoryMoves.move_magazine(_inventory, _store, InventoryMoves.Place.RIG, 0, InventoryMoves.Place.BACKPACK)
	assert_bool(result["ok"]).is_false()
	assert_str(String(result["reason"])).is_equal("full")
	assert_int(_inventory.pouches.size()).is_equal(1)
	assert_int(_inventory.backpack.size()).is_equal(2)
	assert_int(_rounds_total()).is_equal(before)


func test_dropping_on_the_same_place_is_refused() -> void:
	_inventory.add_magazine(Magazine.new(STANAG))
	var result: Dictionary = InventoryMoves.move_magazine(_inventory, _store, InventoryMoves.Place.RIG, 0, InventoryMoves.Place.RIG)
	assert_str(String(result["reason"])).is_equal("same_slot")
	assert_int(_inventory.pouches.size()).is_equal(1)


func test_a_missing_source_slot_is_empty() -> void:
	var result: Dictionary = InventoryMoves.move_magazine(_inventory, _store, InventoryMoves.Place.RIG, 3, InventoryMoves.Place.BACKPACK)
	assert_str(String(result["reason"])).is_equal("empty")


func test_a_magazine_cannot_be_moved_into_a_gun_slot_here() -> void:
	_inventory.add_magazine(Magazine.new(STANAG))
	var result: Dictionary = InventoryMoves.move_magazine(_inventory, _store, InventoryMoves.Place.RIG, 0, InventoryMoves.Place.GUN)
	assert_bool(result["ok"]).is_false()


func test_only_the_rig_reloads_a_gun() -> void:
	assert_bool(InventoryMoves.can_reload_from(InventoryMoves.Place.RIG)["ok"]).is_true()
	for place: InventoryMoves.Place in [InventoryMoves.Place.BACKPACK, InventoryMoves.Place.CONTAINER]:
		var result: Dictionary = InventoryMoves.can_reload_from(place)
		assert_bool(result["ok"]).is_false()
		assert_str(String(result["reason"])).is_equal("move_to_rig")


func test_loose_rounds_move_between_backpack_and_container_without_loss() -> void:
	_inventory.add_loose(FMJ.id, 10)
	var before: int = _rounds_total()
	assert_bool(InventoryMoves.move_loose(_inventory, _store, FMJ.id, 4, InventoryMoves.Place.CONTAINER)["ok"]).is_true()
	assert_int(_store.loose_count(FMJ.id)).is_equal(4)
	assert_int(_inventory.loose_count(FMJ.id)).is_equal(6)
	assert_bool(InventoryMoves.move_loose(_inventory, _store, FMJ.id, 99, InventoryMoves.Place.BACKPACK)["ok"]).is_true()
	assert_int(_inventory.loose_count(FMJ.id)).is_equal(10)
	assert_int(_rounds_total()).is_equal(before)


func test_moving_loose_rounds_that_are_not_there_is_empty() -> void:
	var result: Dictionary = InventoryMoves.move_loose(_inventory, _store, FMJ.id, 5, InventoryMoves.Place.CONTAINER)
	assert_str(String(result["reason"])).is_equal("empty")


func test_packing_checks_caliber_and_room() -> void:
	assert_bool(InventoryMoves.can_pack(Magazine.new(STANAG), FMJ)["ok"]).is_true()
	assert_str(String(InventoryMoves.can_pack(Magazine.new(STANAG), NINE)["reason"])).is_equal("wrong_fit")
	assert_str(String(InventoryMoves.can_pack(Magazine.full_of(GLOCK_17, NINE), NINE)["reason"])).is_equal("full")


func test_refusals_have_toast_text_except_same_slot() -> void:
	assert_str(InventoryMoves.reason_text(&"move_to_rig")).is_equal("MOVE IT TO THE RIG FIRST")
	assert_str(InventoryMoves.reason_text(&"same_slot")).is_empty()


func test_the_backpack_is_full_when_loose_ammo_uses_its_slots() -> void:
	_inventory.add_loose(FMJ.id, 120)
	assert_int(_inventory.free_slots()).is_equal(0)
	_inventory.add_magazine(Magazine.full_of(STANAG, FMJ))
	var result: Dictionary = InventoryMoves.move_magazine(_inventory, _store, InventoryMoves.Place.RIG, 0, InventoryMoves.Place.BACKPACK)
	assert_str(String(result["reason"])).is_equal("full")
	assert_int(_inventory.pouches.size()).is_equal(1)


func test_loose_rounds_move_to_the_backpack_only_as_far_as_the_slots_allow() -> void:
	_store.add_loose(FMJ.id, 200)
	var before: int = _rounds_total()
	var result: Dictionary = InventoryMoves.move_loose(_inventory, _store, FMJ.id, 200, InventoryMoves.Place.BACKPACK)
	assert_bool(result["ok"]).is_true()
	assert_int(_inventory.loose_count(FMJ.id)).is_equal(120)
	assert_int(_store.loose_count(FMJ.id)).is_equal(80)
	assert_int(_rounds_total()).is_equal(before)
	assert_str(String(InventoryMoves.move_loose(_inventory, _store, FMJ.id, 10, InventoryMoves.Place.BACKPACK)["reason"])).is_equal("full")
