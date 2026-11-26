extends GdUnitTestSuite
## Ammo and magazine pickups on the real course: taking them, full slots, and checkpoints.

const COURSE_SCENE: PackedScene = preload("res://game/levels/graybox/movement_course.tscn")

var _course: Node3D
var _player: Player
var _toasts: Array[String] = []
var _listener: Callable


func before_test() -> void:
	Saves.delete_checkpoint()
	Saves.pending = {}
	_course = COURSE_SCENE.instantiate()
	add_child(_course)
	await _ticks(3)
	_player = _course.get_node("Player")
	_toasts.clear()
	_listener = func(text: String) -> void: _toasts.append(text)
	EventBus.toast_requested.connect(_listener)


func after_test() -> void:
	EventBus.toast_requested.disconnect(_listener)
	_course.queue_free()
	await get_tree().process_frame
	Saves.delete_checkpoint()
	Saves.pending = {}


func _pickup(id: StringName) -> AmmoPickup:
	for node: Node in get_tree().get_nodes_in_group(&"pickups"):
		if (node as AmmoPickup).pickup_id == id:
			return node as AmmoPickup
	return null


func test_the_course_has_pickups() -> void:
	assert_object(_pickup(&"pickup_loose_556")).is_not_null()
	assert_object(_pickup(&"pickup_mag_ap")).is_not_null()


func test_pickups_show_3d_models_when_the_type_has_one() -> void:
	var box: AmmoPickup = _pickup(&"pickup_loose_556")
	var mag: AmmoPickup = _pickup(&"pickup_mag_ap")
	for pickup: AmmoPickup in [box, mag]:
		assert_bool(pickup._box.visible).is_false()
		assert_bool(pickup._icon.visible).is_false()
		assert_array(pickup.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return n != pickup._box)).is_not_empty()
	var label: MeshInstance3D = box.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return n != box._box)[0]
	var overrides: Array = range(label.mesh.get_surface_count()).map(func(i: int) -> Material: return label.get_surface_override_material(i))
	assert_array(overrides.filter(func(m: Material) -> bool: return m != null)).has_size(1)


func test_taking_loose_ammo_adds_it_to_the_inventory() -> void:
	var before: int = _player.inventory.loose_count(&"fmj_556")
	var pickup: AmmoPickup = _pickup(&"pickup_loose_556")
	pickup._interactable.complete(_player)
	assert_int(_player.inventory.loose_count(&"fmj_556")).is_equal(before + 30)
	assert_bool(pickup.is_taken).is_true()
	assert_bool(pickup.visible).is_false()
	assert_bool(pickup._interactable.can_interact(_player)).is_false()
	assert_array(_toasts).has_size(1)


func test_taking_a_magazine_fills_a_pouch_with_its_rounds() -> void:
	var before: int = _player.inventory.pouches.size()
	_pickup(&"pickup_mag_ap")._interactable.complete(_player)
	assert_int(_player.inventory.pouches.size()).is_equal(before + 1)
	var taken: Magazine = _player.inventory.pouches.back()
	assert_int(taken.count()).is_equal(30)
	assert_str(String(taken.top())).is_equal("ap_556")


func test_a_magazine_goes_to_the_backpack_when_the_rig_is_full() -> void:
	while _player.inventory.pouches.size() < _player.inventory.pouch_count:
		_player.inventory.add_magazine(Magazine.new(preload("res://data/magazines/stanag_30.tres")))
	var pickup: AmmoPickup = _pickup(&"pickup_mag_ap")
	pickup._interactable.complete(_player)
	assert_bool(pickup.is_taken).is_true()
	assert_int(_player.inventory.backpack.size()).is_equal(1)


func test_a_magazine_stays_when_the_rig_and_backpack_are_full() -> void:
	while _player.inventory.pouches.size() < _player.inventory.pouch_count:
		_player.inventory.add_magazine(Magazine.new(preload("res://data/magazines/stanag_30.tres")))
	while _player.inventory.free_slots() > 0:
		_player.inventory.add_to_backpack(Magazine.new(preload("res://data/magazines/stanag_30.tres")))
	var pickup: AmmoPickup = _pickup(&"pickup_mag_ap")
	pickup._interactable.complete(_player)
	assert_bool(pickup.is_taken).is_false()
	assert_bool(pickup.visible).is_true()
	assert_array(_toasts).contains(["NO ROOM IN THE RIG OR BACKPACK"])


func test_the_player_can_look_at_a_pickup_and_take_it_with_the_interact_key() -> void:
	var intent: InputIntent = InputIntent.new()
	_player.set_scripted_intent(intent)
	var pickup: AmmoPickup = _pickup(&"pickup_loose_556")
	_player.global_position = pickup.global_position + Vector3(0.0, 0.1, 1.2)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	# Looking down at it, as one would at something on the floor.
	_player._pitch = -0.84
	assert_bool(pickup._label.visible).is_false()
	await _ticks(4)
	assert_object(_player.interactor.focus).is_not_null()
	assert_bool(pickup._label.visible).is_true()
	intent.interact = true
	intent.interact_pressed = true
	await _ticks(2)
	intent.interact = false
	intent.interact_pressed = false
	assert_bool(pickup.is_taken).is_true()
	assert_bool(pickup._label.visible).is_false()


func test_taken_pickups_stay_taken_after_a_checkpoint_restore() -> void:
	_pickup(&"pickup_loose_556")._interactable.complete(_player)
	assert_bool(Saves.save_checkpoint()).is_true()
	var data: Dictionary = Saves.read_checkpoint()
	assert_bool(data["world"]["pickups"]["pickup_loose_556"]["taken"]).is_true()
	assert_bool(data["world"]["pickups"]["pickup_loose_9"]["taken"]).is_false()
	_course.queue_free()
	await get_tree().process_frame
	_course = COURSE_SCENE.instantiate()
	add_child(_course)
	await _ticks(3)
	Saves.apply(data)
	await _ticks(3)
	assert_bool(_pickup(&"pickup_loose_556").is_taken).is_true()
	assert_bool(_pickup(&"pickup_loose_9").is_taken).is_false()


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_loose_ammo_only_takes_what_fits_the_backpack_slots() -> void:
	var inventory: AmmoInventory = _player.inventory
	# Leave room for 70 more 5.56 rounds: the rest of the stack in progress plus one free slot.
	var fmj: StringName = &"fmj_556"
	while inventory.free_slots() > 1:
		inventory.add_to_backpack(Magazine.new(preload("res://data/magazines/stanag_30.tres")))
	var before: int = inventory.loose_count(fmj)
	var room: int = inventory.loose_room(fmj)
	var pickup: AmmoPickup = _pickup(&"pickup_loose_556")
	pickup.count = room + 25
	pickup._interactable.complete(_player)
	assert_int(inventory.loose_count(fmj)).is_equal(before + room)
	assert_bool(pickup.is_taken).is_false()
	assert_int(pickup.count).is_equal(25)
	assert_array(_toasts).contains(["TOOK %d, BACKPACK FULL" % room])
