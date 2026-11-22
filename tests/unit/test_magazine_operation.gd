extends GdUnitTestSuite
## Filling and unloading a magazine round by round.

const STANAG: MagazineType = preload("res://data/magazines/stanag_30.tres")
const FMJ: AmmoType = preload("res://data/ammo/fmj_556.tres")
const AP: AmmoType = preload("res://data/ammo/ap_556.tres")
const SETTINGS: InventorySettings = preload("res://data/inventory/inventory_settings.tres")


func _inventory(loose: int) -> AmmoInventory:
	var inventory: AmmoInventory = AmmoInventory.new(4)
	inventory.add_loose(FMJ.id, loose)
	return inventory


func test_a_round_moves_when_its_time_has_run_out() -> void:
	var inventory: AmmoInventory = _inventory(10)
	var magazine: Magazine = Magazine.new(STANAG)
	var operation: MagazineOperation = MagazineOperation.new(MagazineOperation.Kind.FILL, magazine, FMJ)
	assert_int(operation.advance(SETTINGS.fill_time_per_round_s * 0.9, inventory, SETTINGS)).is_equal(0)
	assert_int(operation.advance(SETTINGS.fill_time_per_round_s * 0.2, inventory, SETTINGS)).is_equal(1)
	assert_int(magazine.count()).is_equal(1)
	assert_int(inventory.loose_count(FMJ.id)).is_equal(9)


func test_a_long_step_moves_several_rounds() -> void:
	var inventory: AmmoInventory = _inventory(10)
	var magazine: Magazine = Magazine.new(STANAG)
	var operation: MagazineOperation = MagazineOperation.new(MagazineOperation.Kind.FILL, magazine, FMJ)
	assert_int(operation.advance(SETTINGS.fill_time_per_round_s * 3.5, inventory, SETTINGS)).is_equal(3)


func test_filling_finishes_when_the_loose_ammo_runs_out() -> void:
	var inventory: AmmoInventory = _inventory(2)
	var magazine: Magazine = Magazine.new(STANAG)
	var operation: MagazineOperation = MagazineOperation.new(MagazineOperation.Kind.FILL, magazine, FMJ)
	assert_int(operation.advance(10.0, inventory, SETTINGS)).is_equal(2)
	assert_bool(operation.is_finished(inventory)).is_true()
	assert_int(magazine.count()).is_equal(2)


func test_filling_finishes_when_the_magazine_is_full() -> void:
	var inventory: AmmoInventory = _inventory(100)
	var magazine: Magazine = Magazine.new(STANAG)
	var operation: MagazineOperation = MagazineOperation.new(MagazineOperation.Kind.FILL, magazine, FMJ)
	assert_int(operation.advance(100.0, inventory, SETTINGS)).is_equal(30)
	assert_bool(operation.is_finished(inventory)).is_true()
	assert_int(inventory.loose_count(FMJ.id)).is_equal(70)


func test_a_magazine_with_other_ammo_cannot_be_filled() -> void:
	var inventory: AmmoInventory = _inventory(10)
	var magazine: Magazine = Magazine.full_of(STANAG, AP)
	magazine.rounds.resize(5)
	var operation: MagazineOperation = MagazineOperation.new(MagazineOperation.Kind.FILL, magazine, FMJ)
	assert_bool(operation.is_finished(inventory)).is_true()
	assert_int(operation.advance(10.0, inventory, SETTINGS)).is_equal(0)


func test_unloading_is_faster_and_returns_the_rounds() -> void:
	assert_float(SETTINGS.unload_time_per_round_s).is_less(SETTINGS.fill_time_per_round_s)
	var inventory: AmmoInventory = _inventory(0)
	var magazine: Magazine = Magazine.full_of(STANAG, FMJ)
	var operation: MagazineOperation = MagazineOperation.new(MagazineOperation.Kind.UNLOAD, magazine)
	assert_int(operation.advance(SETTINGS.unload_time_per_round_s * 4.5, inventory, SETTINGS)).is_equal(4)
	assert_int(magazine.count()).is_equal(26)
	assert_int(inventory.loose_count(FMJ.id)).is_equal(4)
	assert_int(operation.advance(100.0, inventory, SETTINGS)).is_equal(26)
	assert_bool(operation.is_finished(inventory)).is_true()


func test_stopping_loses_no_rounds() -> void:
	var inventory: AmmoInventory = _inventory(5)
	var magazine: Magazine = Magazine.new(STANAG)
	var operation: MagazineOperation = MagazineOperation.new(MagazineOperation.Kind.FILL, magazine, FMJ)
	operation.advance(SETTINGS.fill_time_per_round_s * 1.6, inventory, SETTINGS)
	assert_int(magazine.count() + inventory.loose_count(FMJ.id)).is_equal(5)
