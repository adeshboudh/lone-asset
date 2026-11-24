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


func test_packing_loose_rounds_into_a_magazine_takes_real_time() -> void:
	await _press_inventory()
	var inventory: AmmoInventory = _player.inventory
	var index: int = inventory.pouches.find_custom(func(m: Magazine) -> bool: return m.is_empty())
	assert_int(index).is_greater_equal(0)
	var loose: int = inventory.loose_count(&"fmj_556")
	_screen.drop({"kind": "loose", "place": InventoryMoves.Place.BACKPACK, "ammo_id": "fmj_556"},
			{"kind": "slot", "place": InventoryMoves.Place.RIG, "index": index})
	for i: int in 10:
		_screen._process(0.3)
	assert_int(inventory.pouches[index].count()).is_equal(10)
	assert_int(inventory.loose_count(&"fmj_556")).is_equal(loose - 10)
	for i: int in 40:
		_screen._process(0.3)
	assert_int(inventory.pouches[index].count()).is_equal(minf(30.0, loose) as int)
	assert_bool(_screen._operation == null).is_true()


func test_dropping_a_magazine_on_unload_returns_its_rounds() -> void:
	await _press_inventory()
	var inventory: AmmoInventory = _player.inventory
	var index: int = inventory.pouches.find_custom(func(m: Magazine) -> bool: return m.count() == 30)
	var loose: int = inventory.loose_count(&"fmj_556")
	_screen.drop({"kind": "magazine", "place": InventoryMoves.Place.RIG, "index": index}, {"kind": "unload"})
	for i: int in 40:
		_screen._process(0.2)
	assert_int(inventory.pouches[index].count()).is_equal(0)
	assert_int(inventory.loose_count(&"fmj_556")).is_equal(loose + 30)


func test_a_packed_magazine_can_be_dragged_onto_the_gun() -> void:
	await _press_inventory()
	var inventory: AmmoInventory = _player.inventory
	var index: int = inventory.pouches.find_custom(func(m: Magazine) -> bool: return m.is_empty())
	_screen.drop({"kind": "loose", "place": InventoryMoves.Place.BACKPACK, "ammo_id": "fmj_556"},
			{"kind": "slot", "place": InventoryMoves.Place.RIG, "index": index})
	for i: int in 40:
		_screen._process(0.3)
	var packed: Magazine = inventory.pouches[index]
	_player.weapon.logic.set_round_count(5)
	_screen.drop({"kind": "magazine", "place": InventoryMoves.Place.RIG, "index": index}, {"kind": "gun", "weapon": 0})
	assert_bool(_player.weapon.logic.is_reloading).is_true()
	await _ticks(400)
	assert_object(_player.weapon.logic.inserted).is_same(packed)


func test_a_backpack_magazine_cannot_be_dragged_onto_the_gun() -> void:
	await _press_inventory()
	var inventory: AmmoInventory = _player.inventory
	inventory.add_to_backpack(Magazine.full_of(preload("res://data/magazines/stanag_30.tres"), preload("res://data/ammo/fmj_556.tres")))
	_player.weapon.logic.set_round_count(5)
	_screen.drop({"kind": "magazine", "place": InventoryMoves.Place.BACKPACK, "index": 0}, {"kind": "gun", "weapon": 0})
	assert_bool(_player.weapon.logic.is_reloading).is_false()
	assert_str(_screen._message.text).is_equal("MOVE IT TO THE RIG FIRST")


func test_a_magazine_moves_between_backpack_and_rig() -> void:
	await _press_inventory()
	var inventory: AmmoInventory = _player.inventory
	var magazine: Magazine = inventory.pouches[0]
	_screen.drop({"kind": "magazine", "place": InventoryMoves.Place.RIG, "index": 0},
			{"kind": "zone", "place": InventoryMoves.Place.BACKPACK})
	assert_bool(inventory.pouches.has(magazine)).is_false()
	assert_object(inventory.backpack[0]).is_same(magazine)
	_screen.drop({"kind": "magazine", "place": InventoryMoves.Place.BACKPACK, "index": 0},
			{"kind": "zone", "place": InventoryMoves.Place.RIG})
	assert_bool(inventory.pouches.has(magazine)).is_true()


func test_a_full_rig_refuses_a_drop_and_loses_nothing() -> void:
	await _press_inventory()
	var inventory: AmmoInventory = _player.inventory
	while inventory.pouches.size() < inventory.pouch_count:
		inventory.add_magazine(Magazine.new(preload("res://data/magazines/stanag_30.tres")))
	var extra: Magazine = Magazine.full_of(preload("res://data/magazines/stanag_30.tres"), preload("res://data/ammo/fmj_556.tres"))
	inventory.add_to_backpack(extra)
	_screen.drop({"kind": "magazine", "place": InventoryMoves.Place.BACKPACK, "index": 0},
			{"kind": "zone", "place": InventoryMoves.Place.RIG})
	assert_int(inventory.pouches.size()).is_equal(inventory.pouch_count)
	assert_object(inventory.backpack[0]).is_same(extra)


func test_the_container_panel_appears_without_moving_the_others() -> void:
	await _press_inventory()
	await _ticks(2)
	var middle_before: Vector2 = _screen._gun_list.get_global_rect().position
	var right_before: Vector2 = _screen._rig_grid.get_global_rect().position
	assert_bool(_screen._container_panel.visible).is_false()
	var store: LootStore = LootStore.new(4)
	store.add_magazine(Magazine.full_of(preload("res://data/magazines/stanag_30.tres"), preload("res://data/ammo/ap_556.tres")))
	_screen.open_container(store, "Crate")
	await _ticks(2)
	assert_bool(_screen._container_panel.visible).is_true()
	assert_bool(_screen.has_container()).is_true()
	assert_vector(_screen._gun_list.get_global_rect().position).is_equal(middle_before)
	assert_vector(_screen._rig_grid.get_global_rect().position).is_equal(right_before)
	_screen.close_container()
	await _ticks(2)
	assert_bool(_screen._container_panel.visible).is_false()
	assert_vector(_screen._rig_grid.get_global_rect().position).is_equal(right_before)


func test_a_container_magazine_moves_to_the_backpack_and_rounds_are_stripped() -> void:
	await _press_inventory()
	var store: LootStore = LootStore.new(4)
	var magazine: Magazine = Magazine.full_of(preload("res://data/magazines/stanag_30.tres"), preload("res://data/ammo/ap_556.tres"))
	store.add_magazine(magazine)
	store.add_magazine(Magazine.full_of(preload("res://data/magazines/stanag_30.tres"), preload("res://data/ammo/fmj_556.tres")))
	_screen.open_container(store, "Crate")
	_screen.drop({"kind": "magazine", "place": InventoryMoves.Place.CONTAINER, "index": 0}, {"kind": "unload"})
	for i: int in 40:
		_screen._process(0.2)
	assert_int(magazine.count()).is_equal(0)
	assert_int(store.loose_count(&"ap_556")).is_equal(30)
	_screen.drop({"kind": "magazine", "place": InventoryMoves.Place.CONTAINER, "index": 1},
			{"kind": "zone", "place": InventoryMoves.Place.BACKPACK})
	assert_int(store.magazines.size()).is_equal(1)
	assert_int(_player.inventory.backpack.size()).is_equal(1)


func test_closing_the_screen_stops_an_operation_and_the_container() -> void:
	await _press_inventory()
	var store: LootStore = LootStore.new(4)
	store.add_magazine(Magazine.full_of(preload("res://data/magazines/stanag_30.tres"), preload("res://data/ammo/ap_556.tres")))
	_screen.open_container(store, "Crate")
	_screen.drop({"kind": "magazine", "place": InventoryMoves.Place.CONTAINER, "index": 0}, {"kind": "unload"})
	assert_bool(_screen._operation != null).is_true()
	_screen.close()
	assert_bool(_screen._operation == null).is_true()
	assert_bool(_screen.has_container()).is_false()


func test_walking_away_closes_the_container() -> void:
	await _press_inventory()
	var anchor: Node3D = auto_free(Node3D.new())
	_arena.add_child(anchor)
	anchor.global_position = _player.global_position + Vector3(10.0, 0.0, 0.0)
	_screen.open_container(LootStore.new(), "Crate", anchor)
	_screen._process(0.1)
	assert_bool(_screen.has_container()).is_false()


func test_a_loose_stack_moves_to_the_container() -> void:
	await _press_inventory()
	var store: LootStore = LootStore.new()
	_screen.open_container(store, "Crate")
	var loose: int = _player.inventory.loose_count(&"fmj_556")
	_screen.drop({"kind": "loose", "place": InventoryMoves.Place.BACKPACK, "ammo_id": "fmj_556"},
			{"kind": "zone", "place": InventoryMoves.Place.CONTAINER})
	assert_int(store.loose_count(&"fmj_556")).is_equal(loose)
	assert_int(_player.inventory.loose_count(&"fmj_556")).is_equal(0)


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


## The UI is designed for 1920x1080: with everything full, every panel stays inside the screen margins.
func test_every_panel_fits_1920_by_1080_when_full() -> void:
	var inventory: AmmoInventory = _player.inventory
	var stanag: MagazineType = preload("res://data/magazines/stanag_30.tres")
	var mixed: Magazine = Magazine.new(stanag)
	MagazineRules.load_round(mixed, preload("res://data/ammo/fmj_556.tres"))
	MagazineRules.load_round(mixed, preload("res://data/ammo/ap_556.tres"))
	while inventory.pouches.size() < inventory.pouch_count:
		inventory.add_magazine(Magazine.full_of(stanag, preload("res://data/ammo/ap_556.tres")))
	while inventory.free_slots() > 4:
		inventory.add_to_backpack(mixed)
	for ammo: AmmoType in InventoryCatalog.default().ammo:
		inventory.add_loose(ammo.id, 120)
	var store: LootStore = LootStore.new(12)
	while store.add_magazine(Magazine.full_of(stanag, preload("res://data/ammo/fmj_556.tres"))):
		pass
	for ammo: AmmoType in InventoryCatalog.default().ammo:
		store.add_loose(ammo.id, 80)
	store.items["field_dressing"] = 3
	_screen.open_container(store, "Fallen guard")
	# The test window is tiny: ask for the standard 1920x1080 picture.
	var window: Window = get_tree().root
	var old_size: Vector2i = window.size
	window.size = Vector2i(1920, 1080)
	await _ticks(4)
	assert_vector(_screen._root.size).is_equal(Vector2(1920.0, 1080.0))
	var limit: Rect2 = Rect2(Vector2(67.0, 67.0), Vector2(1920.0 - 134.0, 1080.0 - 134.0))
	for panel: Node in _screen.find_children("*", "GlassPanel", true, false):
		var rect: Rect2 = (panel as Control).get_global_rect()
		assert_bool(limit.encloses(rect)) \
			.override_failure_message("panel %s is %s, limit %s" % [panel.name, rect, limit]).is_true()
	# Nothing is hidden: every cell is inside its panel and no two cells overlap (loose ammo under the unload cell).
	var cells: Array[Control] = []
	for node: Node in _screen.find_children("*", "Button", true, false):
		if node is ItemSlot and (node as Control).is_visible_in_tree():
			cells.append(node as Control)
	assert_int(cells.size()).is_greater(30)
	for i: int in cells.size():
		var rect: Rect2 = cells[i].get_global_rect()
		assert_bool(limit.encloses(rect)).override_failure_message("cell %d is %s" % [i, rect]).is_true()
		for j: int in range(i + 1, cells.size()):
			assert_bool(rect.intersects(cells[j].get_global_rect())) \
				.override_failure_message("cells %d and %d overlap: %s %s" % [i, j, rect, cells[j].get_global_rect()]).is_false()
	for panel: Node in _screen.find_children("*", "GlassPanel", true, false):
		var panel_rect: Rect2 = (panel as Control).get_global_rect()
		for cell: Control in cells:
			if panel.is_ancestor_of(cell):
				assert_bool(panel_rect.encloses(cell.get_global_rect())) \
					.override_failure_message("a cell sticks out of its panel: %s in %s" % [cell.get_global_rect(), panel_rect]).is_true()
	window.size = old_size
