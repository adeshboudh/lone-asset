extends GdUnitTestSuite
## Player noise (footsteps, landing, shots, surfaces) and light exposure, with scripted input.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

var _arena: Node3D
var _floor: StaticBody3D
var _player: Player
var _intent: InputIntent
var _lighting: LevelLighting


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	_lighting = LevelLighting.new()
	_lighting.ambient_light_level = 0.8
	_arena.add_child(_lighting)
	_floor = _add_box(Vector3(80.0, 1.0, 80.0), Vector3(0.0, -0.5, 0.0))
	_arena.add_child(BallisticsSystem.new())
	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	_intent = InputIntent.new()
	_player.set_scripted_intent(_intent)
	await _ticks(10)


func test_standing_still_makes_no_noise() -> void:
	var sensor: Array = _sensor(Vector3(1.0, 0.0, 0.0))
	await _ticks(90)
	assert_int(sensor[1].size()).is_equal(0)


func test_walking_is_heard_at_3m_but_not_at_6m() -> void:
	var close: Array = _sensor(Vector3(3.0, 0.0, -2.0))
	var far: Array = _sensor(Vector3(6.0, 0.0, -2.0))
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(90)
	assert_int(close[1].size()).is_greater(0)
	assert_str(close[1][0].type).is_equal(NoiseEvent.FOOTSTEP_WALK)
	assert_int(far[1].size()).is_equal(0)


func test_sprinting_is_heard_at_10m() -> void:
	var sensor: Array = _sensor(Vector3(10.0, 0.0, -3.0))
	_intent.move = Vector2(0.0, 1.0)
	_intent.sprint = true
	await _ticks(90)
	assert_int(sensor[1].size()).is_greater(0)
	assert_str(sensor[1][0].type).is_equal(NoiseEvent.FOOTSTEP_SPRINT)


func test_crouch_walking_is_quiet() -> void:
	_intent.crouch_toggled = true
	await _ticks(1)
	_intent.crouch_toggled = false
	await _ticks(20)
	var close: Array = _sensor(Vector3(1.0, 0.0, -2.0))
	var farther: Array = _sensor(Vector3(3.0, 0.0, -2.0))
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(120)
	assert_int(close[1].size()).is_greater(0)
	assert_str(close[1][0].type).is_equal(NoiseEvent.FOOTSTEP_CROUCH)
	assert_int(farther[1].size()).is_equal(0)


func test_landing_from_a_jump_is_heard() -> void:
	var sensor: Array = _sensor(Vector3(6.0, 0.0, 0.0))
	_intent.jump = true
	await _ticks(1)
	_intent.jump = false
	await _ticks(90)
	assert_int(sensor[1].size()).is_equal(1)
	assert_str(sensor[1][0].type).is_equal(NoiseEvent.LANDING)


func test_suppressed_shot_carries_18m() -> void:
	var inside: Array = _sensor(Vector3(17.0, 0.0, 0.0))
	var outside: Array = _sensor(Vector3(19.0, 0.0, 0.0))
	await _ticks(1)
	_fire_once()
	await _ticks(3)
	var types: Array = inside[1].map(func(entry: Dictionary) -> StringName: return entry["type"])
	assert_array(types).contains([NoiseEvent.SHOT_SUPPRESSED])
	assert_int(outside[1].size()).is_equal(0)


func test_footsteps_louder_on_metal_quieter_on_grass() -> void:
	_floor.set_meta(&"surface", &"metal")
	var at_5m: Array = _sensor(Vector3(5.0, 0.0, -2.5))   # walking radius 4 * 1.5 = 6: heard
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(60)
	assert_int(at_5m[1].size()).is_greater(0)

	_floor.set_meta(&"surface", &"grass")
	var at_3_5m: Array = _sensor(Vector3(3.5, 0.0, -9.0))  # walking radius 4 * 0.7 = 2.8: not heard
	await _ticks(60)
	assert_int(at_3_5m[1].size()).is_equal(0)


func test_exposure_is_ambient_without_volumes() -> void:
	assert_float(_player.exposure.light_level).is_equal(0.8)
	assert_float(_player.exposure.exposure).is_equal(0.8)
	assert_object(_player.exposure.active_volume).is_null()


func test_light_volume_overrides_ambient_and_restores_on_exit() -> void:
	var volume: LightVolume = _volume(Vector3(0.0, 1.0, 0.0), 0.15, 1)
	await _ticks(5)
	assert_float(_player.exposure.light_level).is_equal(0.15)
	assert_object(_player.exposure.active_volume).is_same(volume)
	_player.global_position = Vector3(20.0, 0.05, 0.0)
	await _ticks(5)
	assert_float(_player.exposure.light_level).is_equal(0.8)


func test_highest_priority_volume_wins() -> void:
	_volume(Vector3(0.0, 1.0, 0.0), 0.5, 1)
	_volume(Vector3(0.0, 1.0, 0.0), 0.05, 7)
	_volume(Vector3(0.0, 1.0, 0.0), 0.9, 3)
	await _ticks(5)
	assert_float(_player.exposure.light_level).is_equal(0.05)


func test_muzzle_flash_raises_exposure_briefly() -> void:
	_volume(Vector3(0.0, 1.0, 0.0), 0.05, 1)
	await _ticks(5)
	_fire_once()
	await _ticks(2)
	var flash: float = _player.weapon.definition.flash_exposure
	assert_float(_player.exposure.exposure).is_equal_approx(flash, 0.001)
	assert_float(_player.exposure.light_level).is_equal(0.05)
	await _ticks(30)
	assert_float(_player.exposure.exposure).is_equal_approx(0.05, 0.001)


func _fire_once() -> void:
	_intent.fire = true
	_intent.fire_pressed = true
	await get_tree().physics_frame
	_intent.fire_pressed = false
	_intent.fire = false


func _volume(position: Vector3, level: float, priority: int) -> LightVolume:
	var volume: LightVolume = LightVolume.new()
	volume.light_level = level
	volume.light_priority = priority
	volume.size = Vector3(4.0, 3.0, 4.0)
	volume.position = position
	_arena.add_child(volume)
	return volume


func _sensor(position: Vector3) -> Array:
	var host: Node3D = Node3D.new()
	host.position = position
	var listener: NoiseListener = NoiseListener.new()
	host.add_child(listener)
	_arena.add_child(host)
	var heard: Array[Dictionary] = []
	listener.heard.connect(func(event: NoiseEvent, distance: float, walls: int) -> void:
		heard.append({"type": event.type, "distance": distance, "walls": walls}))
	return [host, heard]


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _add_box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = position
	_arena.add_child(body)
	return body
