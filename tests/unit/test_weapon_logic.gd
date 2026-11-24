extends GdUnitTestSuite
## WeaponLogic: exact fire rate at any tick rate, fire modes, magazine and reload.

const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_suppressed.tres")


func _logic(mode: StringName) -> WeaponLogic:
	var logic: WeaponLogic = WeaponLogic.new(RIFLE)
	while logic.fire_mode != mode:
		logic.toggle_fire_mode()
	return logic


## Rounds fired holding the trigger for `seconds` at `tick_rate` ticks per second.
func _hold(logic: WeaponLogic, seconds: float, tick_rate: int) -> int:
	var shots: int = 0
	var ticks: int = roundi(seconds * tick_rate)
	for i: int in ticks:
		shots += logic.update(1.0 / tick_rate, true, i == 0)
	return shots


func test_auto_fire_rate_is_exact_at_any_tick_rate() -> void:
	# 600 rpm = one round every 0.1 s: rounds at 0.0, 0.1 … 0.9 → 10 in 0.95 s (a whole second would end exactly
	# on the 11th round, which a tick rate may or may not catch).
	for tick_rate: int in [30, 60, 144]:
		assert_int(_hold(_logic(&"auto"), 0.95, tick_rate)) \
			.override_failure_message("at %d ticks/s" % tick_rate).is_equal(10)


func test_semi_fires_once_per_press() -> void:
	var logic: WeaponLogic = _logic(&"semi")
	assert_int(_hold(logic, 0.5, 60)).is_equal(1)


func test_semi_respects_fire_rate() -> void:
	var logic: WeaponLogic = _logic(&"semi")
	assert_int(logic.update(1.0 / 60.0, true, true)).is_equal(1)
	# Pressed again 1/60 s later: faster than 600 rpm allows.
	assert_int(logic.update(1.0 / 60.0, true, true)).is_equal(0)


const STANAG: MagazineType = preload("res://data/magazines/stanag_30.tres")
const FMJ: AmmoType = preload("res://data/ammo/fmj_556.tres")
const AP: AmmoType = preload("res://data/ammo/ap_556.tres")


## A rifle logic with pouches holding the given magazines (round counts of 5.56 FMJ).
func _with_pouches(counts: Array) -> WeaponLogic:
	var inventory: AmmoInventory = AmmoInventory.new(6)
	for count: int in counts:
		var magazine: Magazine = Magazine.new(STANAG)
		for i: int in count:
			magazine.rounds.append(FMJ.id)
		inventory.add_magazine(magazine)
	var logic: WeaponLogic = _logic(&"auto")
	logic.inventory = inventory
	return logic


func _run(logic: WeaponLogic, seconds: float) -> void:
	for i: int in roundi(seconds * 60.0) + 1:
		logic.update(1.0 / 60.0, false, false)


func test_a_new_gun_holds_a_full_magazine_plus_a_chambered_round() -> void:
	var logic: WeaponLogic = _logic(&"auto")
	assert_int(logic.inserted.count()).is_equal(RIFLE.default_magazine.capacity)
	assert_str(String(logic.chambered)).is_equal(String(RIFLE.default_ammo.id))
	assert_int(logic.magazine).is_equal(RIFLE.default_magazine.capacity + 1)


func test_the_gun_fires_every_round_then_goes_dry() -> void:
	var logic: WeaponLogic = _logic(&"auto")
	var rounds: int = logic.magazine
	assert_int(_hold(logic, 5.0, 60)).is_equal(rounds)
	assert_int(logic.magazine).is_equal(0)
	assert_str(String(logic.chambered)).is_empty()


func test_the_top_round_fires_first_and_reports_its_ammo() -> void:
	var logic: WeaponLogic = _logic(&"semi")
	logic.inserted.rounds.append(AP.id)
	logic.chambered = FMJ.id
	logic.update(1.0 / 60.0, true, true)
	assert_array(logic.fired_ammo).is_equal([FMJ.id])
	assert_str(String(logic.chambered)).is_equal(String(AP.id))


func test_tactical_reload_swaps_in_the_fullest_magazine_and_keeps_the_chambered_round() -> void:
	var logic: WeaponLogic = _with_pouches([10, 30, 20])
	_hold(logic, 0.45, 60)
	var chambered: StringName = logic.chambered
	assert_bool(logic.start_reload()).is_true()
	assert_bool(logic.reload_is_empty).is_false()
	_run(logic, RIFLE.reload_time)
	assert_bool(logic.is_reloading).is_false()
	assert_int(logic.inserted.count()).is_equal(30)
	assert_str(String(logic.chambered)).is_equal(String(chambered))
	# The old magazine took the place of the one that went in; nothing was lost.
	assert_array(logic.inventory.pouches.map(func(m: Magazine) -> int: return m.count())).contains_exactly([10, 25, 20])


func test_empty_reload_takes_longer_and_chambers_a_round() -> void:
	var logic: WeaponLogic = _with_pouches([30])
	_hold(logic, 5.0, 60)
	assert_bool(logic.start_reload()).is_true()
	assert_bool(logic.reload_is_empty).is_true()
	_run(logic, RIFLE.reload_time)
	assert_bool(logic.is_reloading).is_true()
	_run(logic, RIFLE.reload_time_empty - RIFLE.reload_time)
	assert_bool(logic.is_reloading).is_false()
	assert_int(logic.magazine).is_equal(30)
	assert_str(String(logic.chambered)).is_not_empty()
	assert_int(logic.inventory.pouches[0].count()).is_equal(0)


func test_pressing_trigger_on_empty_starts_reload() -> void:
	var logic: WeaponLogic = _with_pouches([30])
	_hold(logic, 5.0, 60)
	logic.update(1.0 / 60.0, false, false)
	logic.update(1.0 / 60.0, true, true)
	assert_bool(logic.is_reloading).is_true()


func test_no_reload_when_the_gun_is_full() -> void:
	var logic: WeaponLogic = _with_pouches([30])
	assert_bool(logic.start_reload()).is_false()
	assert_str(String(logic.reload_block)).is_equal("full")


func test_no_reload_without_a_fuller_compatible_magazine() -> void:
	var logic: WeaponLogic = _with_pouches([3])
	_hold(logic, 0.45, 60)
	logic.inserted.rounds.resize(5)
	assert_bool(logic.start_reload()).is_false()
	assert_str(String(logic.reload_block)).is_equal("no_magazine")
	logic.inventory.pouches.clear()
	assert_bool(logic.can_reload()).is_false()


func test_a_glock_magazine_does_not_fit_the_rifle() -> void:
	var logic: WeaponLogic = _with_pouches([])
	var glock_magazine: Magazine = Magazine.full_of(preload("res://data/magazines/glock_17rd.tres"), preload("res://data/ammo/fmj_9.tres"))
	logic.inventory.add_magazine(glock_magazine)
	_hold(logic, 0.45, 60)
	assert_bool(logic.start_reload()).is_false()


func test_cannot_fire_while_reloading() -> void:
	var logic: WeaponLogic = _with_pouches([30])
	_hold(logic, 0.2, 60)
	logic.start_reload()
	assert_int(_hold(logic, 1.0, 60)).is_equal(0)


func test_fire_mode_cycles() -> void:
	var logic: WeaponLogic = WeaponLogic.new(RIFLE)
	var first: StringName = logic.fire_mode
	logic.toggle_fire_mode()
	assert_str(String(logic.fire_mode)).is_not_equal(String(first))
	logic.toggle_fire_mode()
	assert_str(String(logic.fire_mode)).is_equal(String(first))


func test_cancelled_reload_loads_nothing() -> void:
	var logic: WeaponLogic = _with_pouches([30])
	logic.set_round_count(5)
	logic.start_reload()
	for i: int in 30:
		logic.update(1.0 / 60.0, false, false)
	logic.cancel_reload()
	assert_bool(logic.is_reloading).is_false()
	for i: int in 300:
		logic.update(1.0 / 60.0, false, false)
	assert_int(logic.magazine).is_equal(5)
	assert_int(logic.inventory.pouches[0].count()).is_equal(30)


func _rifle_with_rig(rig: Array[Magazine]) -> WeaponLogic:
	var inventory: AmmoInventory = AmmoInventory.new(4)
	for magazine: Magazine in rig:
		inventory.add_magazine(magazine)
	var logic: WeaponLogic = WeaponLogic.new(RIFLE, inventory)
	logic.set_round_count(5)
	return logic


func test_reload_with_takes_the_chosen_magazine_not_the_best() -> void:
	var stanag: MagazineType = RIFLE.default_magazine
	var ammo: AmmoType = RIFLE.default_ammo
	var small: Magazine = Magazine.new(stanag, [ammo.id, ammo.id, ammo.id, ammo.id, ammo.id, ammo.id, ammo.id, ammo.id])
	var big: Magazine = Magazine.full_of(stanag, ammo)
	var logic: WeaponLogic = _rifle_with_rig([big, small])
	assert_bool(logic.start_reload_with(1)).is_true()
	logic.update(10.0, false, false)
	assert_object(logic.inserted).is_same(small)
	assert_bool(logic.inventory.pouches.has(big)).is_true()


func test_reload_with_refuses_another_family_and_bad_index() -> void:
	var glock: MagazineType = preload("res://data/magazines/glock_17rd.tres")
	var logic: WeaponLogic = _rifle_with_rig([Magazine.full_of(glock, preload("res://data/ammo/fmj_9.tres"))])
	assert_bool(logic.start_reload_with(0)).is_false()
	assert_str(String(logic.reload_block)).is_equal("wrong_fit")
	assert_bool(logic.start_reload_with(7)).is_false()
	assert_str(String(logic.reload_block)).is_equal("no_magazine")


func test_reload_with_a_magazine_moved_away_keeps_the_gun_magazine() -> void:
	var magazine: Magazine = Magazine.full_of(RIFLE.default_magazine, RIFLE.default_ammo)
	var logic: WeaponLogic = _rifle_with_rig([magazine])
	var before: Magazine = logic.inserted
	assert_bool(logic.start_reload_with(0)).is_true()
	logic.inventory.pouches.clear()
	logic.update(10.0, false, false)
	assert_object(logic.inserted).is_same(before)
	assert_bool(logic.is_reloading).is_false()
