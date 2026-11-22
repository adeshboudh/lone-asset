extends GdUnitTestSuite
## Reloading with magazines from the pouches, the dry click, ammo effects and old saves, on the real player.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

var _arena: Node3D
var _player: Player
var _intent: InputIntent
var _blocked: Array[StringName] = []
var _listener: Callable


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	_arena.add_child(BallisticsSystem.new())
	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	_intent = InputIntent.new()
	_player.set_scripted_intent(_intent)
	_blocked.clear()
	_listener = func(reason: StringName) -> void: _blocked.append(reason)
	EventBus.reload_blocked.connect(_listener)


func after_test() -> void:
	EventBus.reload_blocked.disconnect(_listener)


func test_the_player_starts_with_pouches_and_loose_ammo() -> void:
	assert_int(_player.inventory.pouches.size()).is_equal(7)
	assert_int(_player.inventory.spare_magazines_for(_player.weapon.definition)).is_equal(3)
	assert_int(_player.weapon.logic.magazine).is_equal(31)


func test_a_reload_swaps_in_a_full_magazine_and_returns_the_old_one() -> void:
	var rifle: Weapon = _player.weapon
	rifle.logic.set_round_count(10)
	await _press_reload()
	await _ticks(260)
	assert_bool(rifle.logic.is_reloading).is_false()
	assert_int(rifle.logic.magazine).is_equal(31)
	var counts: Array = _player.inventory.pouches.map(func(m: Magazine) -> int: return m.count())
	assert_array(counts).contains([9])
	assert_int(counts.size()).is_equal(7)


func test_reload_with_no_fitting_magazine_clicks_and_says_so() -> void:
	var rifle: Weapon = _player.weapon
	rifle.logic.set_round_count(10)
	_player.inventory.pouches.clear()
	await _press_reload()
	await _ticks(3)
	assert_bool(rifle.logic.is_reloading).is_false()
	assert_array(_blocked).contains([&"no_magazine"])


func test_a_full_gun_does_not_reload_or_complain() -> void:
	await _press_reload()
	await _ticks(3)
	assert_bool(_player.weapon.logic.is_reloading).is_false()
	assert_array(_blocked).is_empty()


func test_the_glock_takes_glock_magazines_and_leaves_the_rifle_ones() -> void:
	_intent.weapon_slot = 2
	await _ticks(2)
	_intent.weapon_slot = 0
	await _ticks(30)
	var glock: Weapon = _player.weapon
	assert_str(String(glock.definition.id)).is_equal("glock_17")
	glock.logic.set_round_count(4)
	await _press_reload()
	await _ticks(260)
	assert_int(glock.logic.magazine).is_equal(18)
	assert_int(_player.inventory.spare_magazines_for(preload("res://data/weapons/rifle_muzzle.tres"))).is_equal(3)


func test_the_chambered_ammo_decides_the_shot_profile() -> void:
	var rifle: Weapon = _player.weapon
	rifle.logic.chambered = &"ap_556"
	_intent.fire_pressed = true
	await _ticks(2)
	_intent.fire_pressed = false
	assert_float(rifle.last_shot_profile.penetration_mult).is_equal(2.0)
	await _ticks(10)
	_intent.fire_pressed = true
	await _ticks(2)
	_intent.fire_pressed = false
	assert_float(rifle.last_shot_profile.penetration_mult).is_equal(1.0)


func test_a_version_1_save_turns_its_reserve_into_magazines() -> void:
	_player.load_state({
		"position": [0.0, 0.5, 0.0],
		"loadout": [{"id": "rifle_muzzle", "mag": 7, "reserve": 100, "variant": 0}],
	})
	assert_int(_player.weapon.logic.magazine).is_equal(7)
	assert_array(_player.inventory.pouches.map(func(m: Magazine) -> int: return m.count())).is_equal([30, 30, 30, 10])
	assert_int(_player.inventory.loose_count(&"fmj_556")).is_equal(0)


func test_the_inventory_and_magazines_survive_a_save_and_load() -> void:
	_player.weapon.logic.set_round_count(12)
	_player.inventory.add_loose(&"ap_556", 5)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_player.save_state()))
	_player.weapon.logic.set_round_count(31)
	_player.inventory.loose.clear()
	_player.load_state(data)
	assert_int(_player.weapon.logic.magazine).is_equal(12)
	assert_int(_player.inventory.loose_count(&"ap_556")).is_equal(5)
	assert_int(_player.inventory.pouches.size()).is_equal(7)


func _press_reload() -> void:
	_intent.reload = true
	await _ticks(2)
	_intent.reload = false


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
