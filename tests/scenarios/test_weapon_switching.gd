extends GdUnitTestSuite
## Weapon slots (number keys), per-weapon ammo, and the knife.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")
const DUMMY: PackedScene = preload("res://game/targets/target_dummy.tscn")

var _arena: Node3D
var _player: Player
var _intent: InputIntent


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_arena.add_child(floor_body)
	_arena.add_child(BallisticsSystem.new())
	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	_intent = InputIntent.new()
	_player.set_scripted_intent(_intent)
	await _ticks(10)


func test_starts_with_the_rifle() -> void:
	assert_str(String(_player.weapon.definition.id)).is_equal("rifle_suppressed")


func test_number_keys_pick_the_weapon() -> void:
	await _press_slot(2)
	assert_str(String(_player.weapon.definition.id)).is_equal("pistol_suppressed")
	await _press_slot(3)
	assert_str(String(_player.weapon.definition.id)).is_equal("knife")
	await _press_slot(1)
	assert_str(String(_player.weapon.definition.id)).is_equal("rifle_suppressed")


func test_missing_slot_changes_nothing() -> void:
	await _press_slot(4)
	assert_str(String(_player.weapon.definition.id)).is_equal("rifle_suppressed")


func test_only_the_weapon_in_hand_is_shown() -> void:
	await _press_slot(2)
	var shown: Array[String] = []
	for node: Node in _player.camera.get_children():
		var weapon: Weapon = node as Weapon
		if weapon != null and weapon.visible:
			shown.append(String(weapon.definition.id))
	assert_array(shown).is_equal(["pistol_suppressed"])


func test_cannot_switch_while_reloading() -> void:
	_player.weapon.logic.magazine = 3
	_intent.reload = true
	await _ticks(2)
	_intent.reload = false
	assert_bool(_player.weapon.logic.is_reloading).is_true()
	await _press_slot(2)
	assert_str(String(_player.weapon.definition.id)).is_equal("rifle_suppressed")


func test_each_weapon_keeps_its_own_ammo() -> void:
	_player.weapon.logic.magazine = 5
	await _press_slot(2)
	assert_int(_player.weapon.logic.magazine).is_equal(15)
	await _press_slot(1)
	assert_int(_player.weapon.logic.magazine).is_equal(5)


func test_save_keeps_every_weapon_and_the_slot() -> void:
	_player.weapon.logic.magazine = 5
	await _press_slot(2)
	_player.weapon.logic.magazine = 9
	var data: Dictionary = _player.save_state()
	await _press_slot(1)
	_player.weapon.logic.magazine = 30
	_player.load_state(data)
	assert_str(String(_player.weapon.definition.id)).is_equal("pistol_suppressed")
	assert_int(_player.weapon.logic.magazine).is_equal(9)
	await _press_slot(1)
	assert_int(_player.weapon.logic.magazine).is_equal(5)


func test_knife_from_behind_kills() -> void:
	await _press_slot(3)
	# The dummy looks along -Z, away from the player: the player is behind it.
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -1.2), 0.0)
	await _ticks(2)
	await _stab()
	assert_bool(HealthComponent.of(dummy).is_dead).is_true()


func test_knife_from_the_front_only_wounds() -> void:
	await _press_slot(3)
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -1.2), PI)
	await _ticks(2)
	await _stab()
	var health: HealthComponent = HealthComponent.of(dummy)
	assert_float(health.health).is_equal_approx(health.max_health - _player.weapon.definition.melee_damage, 0.01)


func test_knife_out_of_reach_misses() -> void:
	await _press_slot(3)
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -6.0), 0.0)
	await _ticks(2)
	await _stab()
	assert_float(HealthComponent.of(dummy).health).is_equal(100.0)


func test_knife_is_heard_only_up_close() -> void:
	await _press_slot(3)
	var close: Array[NoiseEvent] = _sensor(Vector3(2.0, 0.0, 0.0))
	var far: Array[NoiseEvent] = _sensor(Vector3(6.0, 0.0, 0.0))
	await _ticks(1)
	await _stab()
	assert_int(close.size()).is_equal(1)
	assert_int(far.size()).is_equal(0)


func _press_slot(slot: int) -> void:
	_intent.weapon_slot = slot
	await _ticks(2)
	_intent.weapon_slot = 0
	await _ticks(2)


func _stab() -> void:
	_intent.fire_pressed = true
	await _ticks(2)
	_intent.fire_pressed = false
	await _ticks(30)


func _dummy(position: Vector3, yaw: float) -> TargetDummy:
	var dummy: TargetDummy = DUMMY.instantiate()
	dummy.position = position
	dummy.rotation.y = yaw
	_arena.add_child(dummy)
	return dummy


func _sensor(position: Vector3) -> Array[NoiseEvent]:
	var host: Node3D = Node3D.new()
	host.position = position
	var listener: NoiseListener = NoiseListener.new()
	host.add_child(listener)
	_arena.add_child(host)
	var heard: Array[NoiseEvent] = []
	listener.heard.connect(func(event: NoiseEvent, _distance: float, _walls: int) -> void: heard.append(event))
	return heard


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
