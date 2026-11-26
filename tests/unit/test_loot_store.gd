extends GdUnitTestSuite
## Container contents: capacity, loose rounds, stripping rounds, saving.

const STANAG: MagazineType = preload("res://data/magazines/stanag_30.tres")
const FMJ: AmmoType = preload("res://data/ammo/fmj_556.tres")
const AP: AmmoType = preload("res://data/ammo/ap_556.tres")


func test_capacity_refuses_an_extra_magazine() -> void:
	var store: LootStore = LootStore.new(1)
	assert_bool(store.add_magazine(Magazine.new(STANAG))).is_true()
	assert_bool(store.add_magazine(Magazine.new(STANAG))).is_false()


func test_take_loose_gives_the_smaller_of_request_and_stock() -> void:
	var store: LootStore = LootStore.new()
	store.add_loose(FMJ.id, 5)
	assert_int(store.take_loose(FMJ.id, 8)).is_equal(5)
	assert_int(store.loose_count(FMJ.id)).is_equal(0)
	assert_int(store.take_loose(FMJ.id, 1)).is_equal(0)


func test_stripping_a_magazine_returns_rounds_to_the_store() -> void:
	var store: LootStore = LootStore.new()
	var magazine: Magazine = Magazine.full_of(STANAG, FMJ)
	store.add_magazine(magazine)
	for i: int in 4:
		assert_bool(store.unload_one(magazine)).is_true()
	assert_int(magazine.count()).is_equal(26)
	assert_int(store.loose_count(FMJ.id)).is_equal(4)


func test_filling_a_store_magazine_uses_store_loose_rounds() -> void:
	var store: LootStore = LootStore.new()
	var magazine: Magazine = Magazine.new(STANAG)
	store.add_loose(AP.id, 1)
	assert_bool(store.fill_one(magazine, AP)).is_true()
	assert_bool(store.fill_one(magazine, AP)).is_false()


func test_store_round_trips_mixed_magazines_and_items() -> void:
	var store: LootStore = LootStore.new(4)
	var magazine: Magazine = Magazine.new(STANAG)
	MagazineRules.load_round(magazine, FMJ)
	MagazineRules.load_round(magazine, AP)
	store.add_magazine(magazine)
	store.add_loose(FMJ.id, 7)
	store.items["bandage"] = 2
	var loaded: LootStore = LootStore.from_dict(store.to_dict(), InventoryCatalog.default())
	assert_int(loaded.capacity).is_equal(4)
	assert_array(loaded.magazines[0].rounds).is_equal([FMJ.id, AP.id])
	assert_int(loaded.loose_count(FMJ.id)).is_equal(7)
	assert_int(int(loaded.items["bandage"])).is_equal(2)
	assert_bool(loaded.is_empty()).is_false()
