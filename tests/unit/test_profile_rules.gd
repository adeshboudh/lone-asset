extends GdUnitTestSuite
## The profile that carries the operative between missions.

const STANAG: MagazineType = preload("res://data/magazines/stanag_30.tres")
const FMJ: AmmoType = preload("res://data/ammo/fmj_556.tres")
const AP: AmmoType = preload("res://data/ammo/ap_556.tres")


func test_build_keeps_the_operative_and_drops_the_place() -> void:
	var state: Dictionary = {"position": [1, 2, 3], "yaw": 0.5, "stance": "stand", "slot": 1, "health": 80.0,
			"condition": {"stress": 20.0}, "inventory": {"pouches": []}, "loadout": []}
	var profile: Dictionary = ProfileRules.build(state)
	for key: String in ["health", "condition", "inventory", "loadout", "profile_version"]:
		assert_bool(profile.has(key)).is_true()
	for key: String in ["position", "yaw", "stance", "slot"]:
		assert_bool(profile.has(key)).is_false()


func test_problem_with_flags_foreign_and_incomplete_files() -> void:
	assert_str(ProfileRules.problem_with({})).is_not_empty()
	assert_str(ProfileRules.problem_with({"profile_version": 1})).is_not_empty()
	assert_str(ProfileRules.problem_with({"profile_version": 99, "inventory": {}})).is_not_empty()
	assert_str(ProfileRules.problem_with({"profile_version": 1, "inventory": {}})).is_empty()


func test_rounds_survive_a_trip_through_text() -> void:
	var inventory: AmmoInventory = AmmoInventory.new(2, 2)
	var magazine: Magazine = Magazine.new(STANAG)
	MagazineRules.load_round(magazine, FMJ)
	MagazineRules.load_round(magazine, AP)
	inventory.add_magazine(magazine)
	inventory.add_loose(AP.id, 9)
	var profile: Dictionary = ProfileRules.build({"inventory": inventory.to_dict(), "health": 55.0})
	var parsed: Dictionary = SaveRules.from_text(SaveRules.to_text(profile))
	assert_str(ProfileRules.problem_with(parsed)).is_empty()
	var loaded: AmmoInventory = AmmoInventory.from_dict(parsed["inventory"], InventoryCatalog.default())
	assert_array(loaded.pouches[0].rounds).is_equal([FMJ.id, AP.id])
	assert_int(loaded.loose_count(AP.id)).is_equal(9)
