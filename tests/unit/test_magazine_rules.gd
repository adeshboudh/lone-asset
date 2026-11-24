extends GdUnitTestSuite
## Magazine fit, loading, fullness and the spare-magazine choice.

const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_muzzle.tres")
const GLOCK: WeaponDefinition = preload("res://data/weapons/glock_17.tres")
const STANAG: MagazineType = preload("res://data/magazines/stanag_30.tres")
const GLOCK_17: MagazineType = preload("res://data/magazines/glock_17rd.tres")
const GLOCK_33: MagazineType = preload("res://data/magazines/glock_33rd.tres")
const FMJ: AmmoType = preload("res://data/ammo/fmj_556.tres")
const AP: AmmoType = preload("res://data/ammo/ap_556.tres")
const NINE: AmmoType = preload("res://data/ammo/fmj_9.tres")


func _mag(type: MagazineType, ammo: AmmoType, count: int) -> Magazine:
	var magazine: Magazine = Magazine.new(type)
	for i: int in count:
		magazine.rounds.append(ammo.id)
	return magazine


func test_magazines_fit_by_family() -> void:
	assert_bool(MagazineRules.can_insert(RIFLE, _mag(STANAG, FMJ, 0))).is_true()
	assert_bool(MagazineRules.can_insert(RIFLE, _mag(GLOCK_17, NINE, 0))).is_false()
	assert_bool(MagazineRules.can_insert(GLOCK, _mag(GLOCK_17, NINE, 0))).is_true()


func test_one_magazine_family_fits_two_capacities() -> void:
	assert_bool(MagazineRules.can_insert(GLOCK, _mag(GLOCK_33, NINE, 0))).is_true()


func test_rounds_load_by_caliber() -> void:
	assert_bool(MagazineRules.can_load(_mag(STANAG, FMJ, 0), FMJ)).is_true()
	assert_bool(MagazineRules.can_load(_mag(STANAG, FMJ, 0), NINE)).is_false()
	assert_bool(MagazineRules.can_load(_mag(GLOCK_17, NINE, 0), FMJ)).is_false()


func test_a_magazine_may_hold_mixed_ammo() -> void:
	assert_bool(MagazineRules.can_load(_mag(STANAG, FMJ, 3), AP)).is_true()
	assert_bool(MagazineRules.can_load(_mag(STANAG, FMJ, 3), FMJ)).is_true()
	assert_bool(MagazineRules.can_load(_mag(STANAG, FMJ, 0), AP)).is_true()


func test_a_full_magazine_takes_no_more() -> void:
	var full: Magazine = _mag(STANAG, FMJ, 30)
	assert_bool(MagazineRules.load_round(full, FMJ)).is_false()
	assert_int(full.count()).is_equal(30)


func test_load_and_unload_move_one_round() -> void:
	var magazine: Magazine = _mag(STANAG, FMJ, 2)
	assert_bool(MagazineRules.load_round(magazine, FMJ)).is_true()
	assert_int(magazine.count()).is_equal(3)
	assert_str(String(MagazineRules.unload_round(magazine))).is_equal(String(FMJ.id))
	assert_int(magazine.count()).is_equal(2)
	assert_str(String(MagazineRules.unload_round(_mag(STANAG, FMJ, 0)))).is_empty()


func test_fullness_labels() -> void:
	assert_str(MagazineRules.fullness_label(_mag(STANAG, FMJ, 0))).is_equal("empty")
	assert_str(MagazineRules.fullness_label(_mag(STANAG, FMJ, 4))).is_equal("nearly empty")
	assert_str(MagazineRules.fullness_label(_mag(STANAG, FMJ, 15))).is_equal("about half")
	assert_str(MagazineRules.fullness_label(_mag(STANAG, FMJ, 25))).is_equal("mostly full")
	assert_str(MagazineRules.fullness_label(_mag(STANAG, FMJ, 30))).is_equal("full")


func test_best_magazine_prefers_the_current_ammo_then_the_fullest_then_the_lowest_index() -> void:
	var pouches: Array[Magazine] = [_mag(STANAG, FMJ, 10), _mag(STANAG, AP, 30), _mag(STANAG, FMJ, 20), _mag(STANAG, FMJ, 20)]
	assert_int(MagazineRules.best_magazine(pouches, RIFLE, FMJ.id, 0)).is_equal(2)
	assert_int(MagazineRules.best_magazine(pouches, RIFLE, AP.id, 0)).is_equal(1)


func test_best_magazine_skips_other_families_empty_and_less_full_ones() -> void:
	var pouches: Array[Magazine] = [_mag(GLOCK_17, NINE, 17), _mag(STANAG, FMJ, 0), _mag(STANAG, FMJ, 8)]
	assert_int(MagazineRules.best_magazine(pouches, RIFLE, FMJ.id, 0)).is_equal(2)
	assert_int(MagazineRules.best_magazine(pouches, RIFLE, FMJ.id, 8)).is_equal(-1)


func test_mixed_magazine_fires_last_loaded_first() -> void:
	var magazine: Magazine = Magazine.new(STANAG)
	MagazineRules.load_round(magazine, FMJ)
	MagazineRules.load_round(magazine, AP)
	assert_array(magazine.rounds).is_equal([FMJ.id, AP.id])
	assert_str(String(MagazineRules.unload_round(magazine))).is_equal(String(AP.id))


func test_wrong_caliber_is_still_refused() -> void:
	assert_bool(MagazineRules.can_load(Magazine.new(STANAG), NINE)).is_false()
