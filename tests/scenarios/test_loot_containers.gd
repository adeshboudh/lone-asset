extends GdUnitTestSuite
## Containers on the real course: the crate, a fallen guard, opening the panel, moving items out, checkpoints.

const COURSE_SCENE: PackedScene = preload("res://game/levels/graybox/movement_course.tscn")

var _course: Node3D
var _player: Player


func before_test() -> void:
	Saves.delete_checkpoint()
	Saves.pending = {}
	_course = COURSE_SCENE.instantiate()
	add_child(_course)
	await _ticks(3)
	_player = _course.get_node("Player")


func after_test() -> void:
	_course.queue_free()
	await get_tree().process_frame
	Saves.delete_checkpoint()
	Saves.pending = {}


func _container(id: StringName) -> LootContainer:
	for node: Node in get_tree().get_nodes_in_group(&"containers"):
		if (node as LootContainer).container_id == id:
			return node as LootContainer
	return null


func test_the_course_has_a_supply_crate_with_mixed_contents() -> void:
	var crate: LootContainer = _container(&"crate_start")
	assert_object(crate).is_not_null()
	assert_int(crate.store.magazines.size()).is_equal(2)
	assert_int(crate.store.loose_count(&"fmj_556")).is_equal(40)


func test_using_a_container_opens_its_panel_on_its_contents() -> void:
	var crate: LootContainer = _container(&"crate_start")
	crate._interactable.complete(_player)
	assert_bool(_player.inventory_screen.is_open).is_true()
	assert_bool(_player.inventory_screen.has_container()).is_true()
	assert_bool(_player.inventory_screen._container_panel.visible).is_true()
	_player.inventory_screen.close()


func test_a_dead_guard_leaves_a_container_with_its_magazine() -> void:
	var guard: Guard = _course.get_node("Guards/GuardB")
	guard.load_state({"position": [-14.0, 0.0, -16.0], "yaw": 0.0, "alive": false})
	await _ticks(3)
	var drop: LootContainer = _container(&"drop_guard_b")
	assert_object(drop).is_not_null()
	assert_int(drop.store.magazines.size()).is_equal(1)
	assert_int(drop.store.magazines[0].count()).is_equal(20)


func test_taking_a_magazine_from_the_container_and_saving_keeps_it_moved() -> void:
	var crate: LootContainer = _container(&"crate_start")
	crate._interactable.complete(_player)
	var screen: InventoryScreen = _player.inventory_screen
	screen.drop({"kind": "magazine", "place": InventoryMoves.Place.CONTAINER, "index": 0},
			{"kind": "zone", "place": InventoryMoves.Place.BACKPACK})
	assert_int(crate.store.magazines.size()).is_equal(1)
	assert_int(_player.inventory.backpack.size()).is_equal(1)
	screen.close()
	assert_bool(Saves.save_checkpoint()).is_true()
	var data: Dictionary = Saves.read_checkpoint()
	assert_int(int(data["schema_version"])).is_equal(3)
	assert_int((data["world"]["containers"]["crate_start"]["magazines"] as Array).size()).is_equal(1)
	_course.queue_free()
	await get_tree().process_frame
	_course = COURSE_SCENE.instantiate()
	add_child(_course)
	await _ticks(3)
	Saves.apply(data)
	await _ticks(3)
	assert_int(_container(&"crate_start").store.magazines.size()).is_equal(1)
	var restored: Player = _course.get_node("Player")
	assert_int(restored.inventory.backpack.size()).is_equal(1)


func test_a_schema_2_checkpoint_loads_with_an_empty_backpack_and_default_condition() -> void:
	assert_bool(Saves.save_checkpoint()).is_true()
	var data: Dictionary = Saves.read_checkpoint()
	data["schema_version"] = 2
	data["player"].erase("condition")
	data["player"]["inventory"].erase("backpack")
	data["player"]["inventory"].erase("backpack_capacity")
	data["world"].erase("containers")
	var migrated: Dictionary = SaveRules.migrate(data)
	_player.condition.stress = 50.0
	Saves.apply(migrated)
	await _ticks(3)
	assert_int(_player.inventory.backpack.size()).is_equal(0)
	assert_float(_player.condition.stress).is_equal(0.0)


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_a_profile_restores_the_operative_but_not_the_place() -> void:
	_player.condition.stress = 42.0
	_player.condition.bleeding = true
	_player.inventory.add_to_backpack(Magazine.full_of(preload("res://data/magazines/stanag_30.tres"), preload("res://data/ammo/ap_556.tres")))
	var profile: Dictionary = SaveRules.from_text(SaveRules.to_text(ProfileRules.build(_player.save_state())))
	_player.condition = OperativeCondition.new()
	_player.inventory.backpack.clear()
	var spot: Vector3 = _player.global_position
	_player.load_profile(profile)
	assert_float(_player.condition.stress).is_equal(42.0)
	assert_bool(_player.condition.bleeding).is_true()
	assert_int(_player.inventory.backpack.size()).is_equal(1)
	assert_vector(_player.global_position).is_equal(spot)
