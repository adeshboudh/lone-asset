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
	# 750 rpm = one round every 0.08 s: rounds at 0.00, 0.08 … 0.96 → 13 in one second.
	for tick_rate: int in [30, 60, 144]:
		assert_int(_hold(_logic(&"auto"), 1.0, tick_rate)) \
			.override_failure_message("at %d ticks/s" % tick_rate).is_equal(13)


func test_semi_fires_once_per_press() -> void:
	var logic: WeaponLogic = _logic(&"semi")
	assert_int(_hold(logic, 0.5, 60)).is_equal(1)


func test_semi_respects_fire_rate() -> void:
	var logic: WeaponLogic = _logic(&"semi")
	assert_int(logic.update(1.0 / 60.0, true, true)).is_equal(1)
	# Pressed again 1/60 s later: faster than 750 rpm allows.
	assert_int(logic.update(1.0 / 60.0, true, true)).is_equal(0)


func test_empty_magazine_stops_firing() -> void:
	var logic: WeaponLogic = _logic(&"auto")
	assert_int(_hold(logic, 5.0, 60)).is_equal(RIFLE.magazine_size)
	assert_int(logic.magazine).is_equal(0)


func test_reload_moves_rounds_from_reserve() -> void:
	var logic: WeaponLogic = _logic(&"auto")
	var fired: int = _hold(logic, 0.4, 60)
	assert_int(fired).is_equal(5)  # rounds at 0.00, 0.08, 0.16, 0.24, 0.32 s
	assert_bool(logic.start_reload()).is_true()
	for i: int in roundi(RIFLE.reload_time * 60.0) + 1:
		logic.update(1.0 / 60.0, false, false)
	assert_bool(logic.is_reloading).is_false()
	assert_int(logic.magazine).is_equal(RIFLE.magazine_size)
	assert_int(logic.reserve).is_equal(RIFLE.reserve_ammo - fired)


func test_empty_reload_takes_longer() -> void:
	var logic: WeaponLogic = _logic(&"auto")
	_hold(logic, 5.0, 60)
	logic.start_reload()
	for i: int in roundi(RIFLE.reload_time * 60.0) + 1:
		logic.update(1.0 / 60.0, false, false)
	assert_bool(logic.is_reloading).is_true()


func test_pressing_trigger_on_empty_starts_reload() -> void:
	var logic: WeaponLogic = _logic(&"auto")
	_hold(logic, 5.0, 60)
	logic.update(1.0 / 60.0, false, false)
	logic.update(1.0 / 60.0, true, true)
	assert_bool(logic.is_reloading).is_true()


func test_no_reload_when_full_or_no_reserve() -> void:
	var logic: WeaponLogic = _logic(&"auto")
	assert_bool(logic.start_reload()).is_false()
	logic.reserve = 0
	_hold(logic, 0.2, 60)
	assert_bool(logic.start_reload()).is_false()


func test_cannot_fire_while_reloading() -> void:
	var logic: WeaponLogic = _logic(&"auto")
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
