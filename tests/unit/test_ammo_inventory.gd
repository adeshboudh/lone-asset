extends GdUnitTestSuite
## Pouches, loose ammo, filling, unloading and saving.

const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_muzzle.tres")
const STANAG: MagazineType = preload("res://data/magazines/stanag_30.tres")
const FMJ: AmmoType = preload("res://data/ammo/fmj_556.tres")
const AP: AmmoType = preload("res://data/ammo/ap_556.tres")


func test_pouches_are_limited() -> void:
	var inventory: AmmoInventory = AmmoInventory.new(2)
	assert_bool(inventory.add_magazine(Magazine.new(STANAG))).is_true()
	assert_bool(inventory.add_magazine(Magazine.new(STANAG))).is_true()
	assert_bool(inventory.add_magazine(Magazine.new(STANAG))).is_false()


func test_filling_moves_loose_rounds_into_the_magazine() -> void:
	var inventory: AmmoInventory = AmmoInventory.new(2)
	inventory.add_loose(FMJ.id, 2)
	var magazine: Magazine = Magazine.new(STANAG)
	assert_bool(inventory.fill_one(magazine, FMJ)).is_true()
	assert_bool(inventory.fill_one(magazine, FMJ)).is_true()
	assert_bool(inventory.fill_one(magazine, FMJ)).is_false()
	assert_int(magazine.count()).is_equal(2)
	assert_int(inventory.loose_count(FMJ.id)).is_equal(0)


func test_filling_refuses_a_second_ammo_type() -> void:
	var inventory: AmmoInventory = AmmoInventory.new(2)
	inventory.add_loose(FMJ.id, 1)
	inventory.add_loose(AP.id, 1)
	var magazine: Magazine = Magazine.new(STANAG)
	inventory.fill_one(magazine, FMJ)
	assert_bool(inventory.fill_one(magazine, AP)).is_false()
	assert_int(inventory.loose_count(AP.id)).is_equal(1)


func test_unloading_returns_rounds_to_loose_ammo() -> void:
	var inventory: AmmoInventory = AmmoInventory.new(2)
	var magazine: Magazine = Magazine.full_of(STANAG, FMJ)
	assert_bool(inventory.unload_one(magazine)).is_true()
	assert_int(magazine.count()).is_equal(29)
	assert_int(inventory.loose_count(FMJ.id)).is_equal(1)
	assert_bool(inventory.unload_one(Magazine.new(STANAG))).is_false()


func test_spare_magazines_counts_only_compatible_non_empty_ones() -> void:
	var inventory: AmmoInventory = AmmoInventory.new(6)
	inventory.add_magazine(Magazine.full_of(STANAG, FMJ))
	inventory.add_magazine(Magazine.new(STANAG))
	inventory.add_magazine(Magazine.full_of(preload("res://data/magazines/glock_17rd.tres"), preload("res://data/ammo/fmj_9.tres")))
	assert_int(inventory.spare_magazines_for(RIFLE)).is_equal(1)


func test_an_old_reserve_becomes_magazines_then_loose_ammo() -> void:
	var inventory: AmmoInventory = AmmoInventory.new(2)
	inventory.stock_reserve(RIFLE, 75)
	assert_int(inventory.pouches.size()).is_equal(2)
	assert_int(inventory.pouches[0].count()).is_equal(30)
	assert_int(inventory.loose_count(RIFLE.default_ammo.id)).is_equal(15)


func test_save_round_trip() -> void:
	var inventory: AmmoInventory = AmmoInventory.new(5)
	inventory.add_magazine(Magazine.full_of(STANAG, AP))
	inventory.add_loose(FMJ.id, 12)
	var restored: AmmoInventory = AmmoInventory.from_dict(JSON.parse_string(JSON.stringify(inventory.to_dict())), InventoryCatalog.default())
	assert_int(restored.pouch_count).is_equal(5)
	assert_int(restored.pouches.size()).is_equal(1)
	assert_int(restored.pouches[0].count()).is_equal(30)
	assert_str(String(restored.pouches[0].top())).is_equal(String(AP.id))
	assert_int(restored.loose_count(FMJ.id)).is_equal(12)


func test_the_starting_loadout_builds_its_inventory() -> void:
	var inventory: AmmoInventory = preload("res://data/inventory/starting_loadout.tres").build()
	assert_int(inventory.pouches.size()).is_equal(7)
	assert_int(inventory.loose_count(FMJ.id)).is_greater(0)
