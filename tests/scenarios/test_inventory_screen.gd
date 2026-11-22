extends GdUnitTestSuite
## The inventory screen on the real player: opening, the busy hands, filling, unloading and closing.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

var _arena: Node3D
var _player: Player
var _intent: InputIntent
var _screen: InventoryScreen


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	_arena.add_child(BallisticsSystem.new())
	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	_intent = InputIntent.new()
	_player.set_scripted_intent(_intent)
	_screen = _player.inventory_screen


func test_the_key_opens_and_closes_the_screen() -> void:
	assert_bool(_screen.is_open).is_false()
	await _press_inventory()
	assert_bool(_screen.is_open).is_true()
	assert_bool(_screen.visible).is_true()
	await _press_inventory()
	assert_bool(_screen.is_open).is_false()
	assert_bool(_screen.visible).is_false()


func test_the_game_is_not_paused_while_it_is_open() -> void:
	await _press_inventory()
	assert_bool(get_tree().paused).is_false()


func test_the_weapon_gets_no_input_while_it_is_open() -> void:
	var before: int = _player.weapon.logic.magazine
	await _press_inventory()
	_intent.fire = true
	_intent.fire_pressed = true
	_intent.reload = true
	await _ticks(10)
	_intent.fire = false
	_intent.fire_pressed = false
	_intent.reload = false
	assert_int(_player.weapon.logic.magazine).is_equal(before)
	assert_bool(_player.weapon.logic.is_reloading).is_false()


func test_the_player_can_still_move_while_it_is_open() -> void:
	await _press_inventory()
	var start: Vector3 = _player.global_position
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(30)
	_intent.move = Vector2.ZERO
	assert_float(_player.global_position.distance_to(start)).is_greater(0.1)


func test_filling_the_empty_magazine_takes_loose_rounds_in_real_time() -> void:
	await _press_inventory()
	var inventory: AmmoInventory = _player.inventory
	var index: int = inventory.pouches.find_custom(func(m: Magazine) -> bool: return m.is_empty())
	assert_int(index).is_greater_equal(0)
	var loose: int = inventory.loose_count(&"fmj_556")
	_screen._select(index)
	_screen._start(MagazineOperation.Kind.FILL, InventoryCatalog.default().find_ammo(&"fmj_556"))
	for i: int in 10:
		_screen._process(0.3)
	assert_int(inventory.pouches[index].count()).is_equal(10)
	assert_int(inventory.loose_count(&"fmj_556")).is_equal(loose - 10)
	for i: int in 40:
		_screen._process(0.3)
	assert_int(inventory.pouches[index].count()).is_equal(minf(30.0, loose) as int)
	assert_bool(_screen._operation == null).is_true()


func test_unloading_a_magazine_returns_its_rounds_to_loose_ammo() -> void:
	await _press_inventory()
	var inventory: AmmoInventory = _player.inventory
	var index: int = inventory.pouches.find_custom(func(m: Magazine) -> bool: return m.count() == 30)
	var loose: int = inventory.loose_count(&"fmj_556")
	_screen._select(index)
	_screen._start(MagazineOperation.Kind.UNLOAD, null)
	for i: int in 40:
		_screen._process(0.2)
	assert_int(inventory.pouches[index].count()).is_equal(0)
	assert_int(inventory.loose_count(&"fmj_556")).is_equal(loose + 30)


func test_a_filled_magazine_can_be_reloaded_into_the_gun() -> void:
	await _press_inventory()
	var inventory: AmmoInventory = _player.inventory
	var index: int = inventory.pouches.find_custom(func(m: Magazine) -> bool: return m.is_empty())
	_screen._select(index)
	_screen._start(MagazineOperation.Kind.FILL, InventoryCatalog.default().find_ammo(&"fmj_556"))
	for i: int in 40:
		_screen._process(0.3)
	# Spend the other spare magazines so the filled one is the only choice.
	for i: int in range(inventory.pouches.size() - 1, -1, -1):
		if i != index:
			inventory.pouches.remove_at(i)
	await _press_inventory()
	_player.weapon.logic.set_round_count(5)
	_intent.reload = true
	await _ticks(2)
	_intent.reload = false
	await _ticks(260)
	assert_int(_player.weapon.logic.inserted.count()).is_equal(30)


func test_the_pause_action_closes_it_first() -> void:
	await _press_inventory()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	_screen._unhandled_input(event)
	assert_bool(_screen.is_open).is_false()


func test_the_pause_menu_and_death_screen_draw_above_it() -> void:
	assert_int(_screen.layer).is_less(_scene_layer(preload("res://game/ui/pause/pause_menu.tscn")))
	assert_int(_screen.layer).is_less(_scene_layer(preload("res://game/ui/death/death_screen.tscn")))


func test_a_death_closes_it() -> void:
	await _press_inventory()
	EventBus.player_died.emit()
	assert_bool(_screen.is_open).is_false()


## The root's `layer` as saved in the scene (no instance needed).
func _scene_layer(scene: PackedScene) -> int:
	var state: SceneState = scene.get_state()
	for i: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"layer":
			return int(state.get_node_property_value(0, i))
	return 1


func _press_inventory() -> void:
	_intent.inventory_toggled = true
	await _ticks(2)
	_intent.inventory_toggled = false
	await _ticks(2)


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
