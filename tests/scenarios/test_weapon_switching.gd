extends GdUnitTestSuite
## The weapon loadout (rifle on key 1, Glock 17 on key 2; the knife is out until it has a rig) and the attachment swap.

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


func test_slot_two_is_the_glock_and_empty_slots_change_nothing() -> void:
	await _press_slot(2)
	assert_str(String(_player.weapon.definition.id)).is_equal("glock_17")
	for slot: int in [3, 4]:
		await _press_slot(slot)
		assert_str(String(_player.weapon.definition.id)).is_equal("glock_17")
	await _ticks(60)
	await _press_slot(1)
	assert_str(String(_player.weapon.definition.id)).is_equal("rifle_muzzle")


func test_the_weapon_is_lowered_before_the_switch_and_cannot_fire_meanwhile() -> void:
	var rifle: Weapon = _player.weapon
	var before: int = rifle.logic.magazine
	_intent.weapon_slot = 2
	await _ticks(3)
	_intent.weapon_slot = 0
	_intent.fire_pressed = true
	await _ticks(2)
	_intent.fire_pressed = false
	assert_str(String(_player.weapon.definition.id)).is_equal("rifle_muzzle")
	assert_int(rifle.logic.magazine).is_equal(before)
	await _ticks(20)
	assert_str(String(_player.weapon.definition.id)).is_equal("glock_17")


func test_switching_during_a_reload_cancels_it_and_loads_no_ammo() -> void:
	var rifle: Weapon = _player.weapon
	rifle.logic.set_round_count(10)
	var spare: Array = _player.inventory.pouches.map(func(m: Magazine) -> int: return m.count())
	_intent.reload = true
	await _ticks(2)
	_intent.reload = false
	assert_bool(rifle.logic.is_reloading).is_true()
	await _press_slot(2)
	assert_str(String(_player.weapon.definition.id)).is_equal("glock_17")
	assert_bool(rifle.logic.is_reloading).is_false()
	assert_int(rifle.logic.magazine).is_equal(10)
	assert_array(_player.inventory.pouches.map(func(m: Magazine) -> int: return m.count())).is_equal(spare)
	await _ticks(300)
	assert_int(rifle.logic.magazine).is_equal(10)


func test_the_glock_flash_and_smoke_are_smaller_than_the_rifle() -> void:
	var glock: WeaponDefinition = load("res://data/weapons/glock_17.tres")
	assert_float(glock.muzzle_flash_scale).is_less(_player.weapon.definition.muzzle_flash_scale)
	assert_float(glock.muzzle_smoke_scale).is_less(_player.weapon.definition.muzzle_smoke_scale)
	assert_float(glock.muzzle_light_energy).is_less(_player.weapon.definition.muzzle_light_energy)


func test_only_the_weapon_in_hand_is_shown() -> void:
	await _press_slot(2)
	var shown: Array[String] = []
	for node: Node in _player.camera.get_children():
		var weapon: Weapon = node as Weapon
		if weapon != null and weapon.visible:
			shown.append(String(weapon.definition.id))
	assert_array(shown).is_equal(["glock_17"])


func test_the_glock_has_its_own_ammo_and_it_is_saved() -> void:
	await _press_slot(2)
	assert_int(_player.weapon.logic.magazine).is_equal(18)
	_player.weapon.logic.set_round_count(5)
	var data: Dictionary = _player.save_state()
	await _ticks(60)
	await _press_slot(1)
	assert_int(_player.weapon.logic.magazine).is_equal(31)
	_player.load_state(data)
	assert_str(String(_player.weapon.definition.id)).is_equal("glock_17")
	assert_int(_player.weapon.logic.magazine).is_equal(5)


func test_glock_attachment_key_swaps_to_the_suppressed_variant() -> void:
	await _press_slot(2)
	await _ticks(60)
	var glock: Weapon = _player.weapon
	glock.logic.set_round_count(11)
	await _press_attachment()
	assert_str(String(glock.definition.id)).is_equal("glock_17_suppressed")
	assert_int(glock.logic.magazine).is_equal(11)
	assert_float(glock.definition.noise_radius_m).is_less(40.0)


func test_save_keeps_the_rifle_ammo() -> void:
	_player.weapon.logic.set_round_count(9)
	var data: Dictionary = _player.save_state()
	_player.weapon.logic.set_round_count(31)
	_player.load_state(data)
	assert_int(_player.weapon.logic.magazine).is_equal(9)


func test_starts_with_the_rifle_unsuppressed() -> void:
	assert_str(String(_player.weapon.definition.id)).is_equal("rifle_muzzle")
	assert_bool(_player.weapon.definition.suppressed).is_false()


func test_every_animation_a_weapon_names_exists_in_its_viewmodel() -> void:
	for slot: int in [1, 2]:
		await _press_slot(slot)
		await _ticks(60)
		var definition: WeaponDefinition = _player.weapon.definition
		var animations: AnimationPlayer = _player.weapon._anim
		assert_object(animations).is_not_null()
		for clip: StringName in [definition.anim_idle, definition.anim_draw, definition.anim_fire, definition.anim_reload,
				definition.anim_reload_empty, definition.anim_fire_alt]:
			if clip != &"":
				assert_bool(animations.has_animation(clip)).override_failure_message("%s missing %s in %s" % [definition.id, clip, animations.get_animation_list()]).is_true()


func test_rifle_shot_leaves_the_muzzle_but_hits_where_the_camera_aims() -> void:
	# No spread, so the shot is deterministic; a copy so the shared resource stays untouched.
	var perfect: WeaponDefinition = _player.weapon.definition.duplicate()
	perfect.spread_hip_deg = 0.0
	perfect.spread_move_add_deg = 0.0
	perfect.spread_per_shot_deg = 0.0
	_player.weapon.definition = perfect
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -12.0), 0.0)
	await _ticks(2)
	_intent.fire_pressed = true
	await _ticks(2)
	_intent.fire_pressed = false
	await _ticks(30)
	assert_float(HealthComponent.of(dummy).health).is_less(100.0)


func test_attachment_key_swaps_muzzle_brake_for_suppressor_and_keeps_ammo() -> void:
	var rifle: Weapon = _player.weapon
	rifle.logic.set_round_count(17)
	await _press_attachment()
	assert_str(String(rifle.definition.id)).is_equal("rifle_suppressed")
	assert_int(rifle.logic.magazine).is_equal(17)
	assert_bool(rifle.definition.suppressed).is_true()
	await _ticks(70)
	await _press_attachment()
	assert_str(String(rifle.definition.id)).is_equal("rifle_muzzle")
	assert_int(rifle.logic.magazine).is_equal(17)


func test_muzzle_brake_is_more_accurate_and_louder_than_the_suppressor() -> void:
	var rifle: Weapon = _player.weapon
	var brake: WeaponDefinition = rifle.definition
	await _press_attachment()
	var suppressed: WeaponDefinition = rifle.definition
	assert_float(brake.spread_hip_deg).is_less(suppressed.spread_hip_deg)
	assert_float(brake.spread_ads_deg).is_less(suppressed.spread_ads_deg)
	assert_float(brake.noise_radius_m).is_greater(suppressed.noise_radius_m)


func test_cannot_fire_while_the_attachment_is_being_swapped() -> void:
	var rifle: Weapon = _player.weapon
	var before: int = rifle.logic.magazine
	_intent.attachment_toggled = true
	await _ticks(2)
	_intent.attachment_toggled = false
	_intent.fire_pressed = true
	await _ticks(2)
	_intent.fire_pressed = false
	assert_int(rifle.logic.magazine).is_equal(before)


func test_fitted_variant_is_saved_and_restored() -> void:
	await _press_attachment()
	var saved: Dictionary = _player.save_state()
	await _ticks(70)
	await _press_attachment()
	assert_str(String(_player.weapon.definition.id)).is_equal("rifle_muzzle")
	_player.load_state(saved)
	assert_str(String(_player.weapon.definition.id)).is_equal("rifle_suppressed")


func _press_attachment() -> void:
	_intent.attachment_toggled = true
	await _ticks(2)
	_intent.attachment_toggled = false
	await _ticks(2)


func _press_slot(slot: int) -> void:
	_intent.weapon_slot = slot
	await _ticks(2)
	_intent.weapon_slot = 0
	# The weapon in hand is put away first (SwitchMotionSettings.holster_time_s), then the new one is raised.
	await _ticks(20)


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
