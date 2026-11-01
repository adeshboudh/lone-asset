extends GdUnitTestSuite
## NoiseSystem delivery: range, wall attenuation, non-blocking characters.

var _arena: Node3D


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	await _ticks(2)


func test_listener_in_range_hears() -> void:
	var sensor: Array = _sensor(Vector3(5.0, 0.0, 0.0))
	await _ticks(1)
	NoiseSystem.emit_noise(NoiseEvent.LANDING, Vector3.ZERO, 8.0)
	assert_int(sensor[1].size()).is_equal(1)
	assert_str(sensor[1][0].type).is_equal(NoiseEvent.LANDING)


func test_listener_out_of_range_does_not_hear() -> void:
	var sensor: Array = _sensor(Vector3(9.0, 0.0, 0.0))
	await _ticks(1)
	NoiseSystem.emit_noise(NoiseEvent.LANDING, Vector3.ZERO, 8.0)
	assert_int(sensor[1].size()).is_equal(0)


func test_one_wall_halves_the_radius() -> void:
	_wall(Vector3(3.0, 1.5, 0.0))
	var near: Array = _sensor(Vector3(5.0, 0.0, 0.0))   # 12 m * 0.5 = 6 m: heard
	var far: Array = _sensor(Vector3(7.0, 0.0, 0.0))    # beyond 6 m: not heard
	await _ticks(2)
	NoiseSystem.emit_noise(NoiseEvent.FOOTSTEP_SPRINT, Vector3.ZERO, 12.0)
	assert_int(near[1].size()).is_equal(1)
	assert_int(near[1][0].walls).is_equal(1)
	assert_int(far[1].size()).is_equal(0)


func test_two_walls_quarter_the_radius() -> void:
	_wall(Vector3(2.0, 1.5, 0.0))
	_wall(Vector3(4.0, 1.5, 0.0))
	var heard: Array = _sensor(Vector3(3.0 + 0.0, 0.0, 0.0))   # between the walls: one wall, 12*0.5=6 → heard
	var behind: Array = _sensor(Vector3(5.0, 0.0, 0.0))        # two walls: 12*0.25=3 < 5 → not heard
	await _ticks(2)
	NoiseSystem.emit_noise(NoiseEvent.FOOTSTEP_SPRINT, Vector3.ZERO, 12.0)
	assert_int(heard[1].size()).is_equal(1)
	assert_int(behind[1].size()).is_equal(0)


func test_low_cover_does_not_muffle() -> void:
	_wall(Vector3(3.0, 0.5, 0.0), Vector3(0.4, 1.0, 6.0))
	var sensor: Array = _sensor(Vector3(7.0, 0.0, 0.0))
	await _ticks(2)
	NoiseSystem.emit_noise(NoiseEvent.FOOTSTEP_SPRINT, Vector3.ZERO, 12.0)
	assert_int(sensor[1][0].walls).is_equal(0)


func test_characters_do_not_block_sound() -> void:
	var dummy: TargetDummy = auto_free((load("res://game/targets/target_dummy.tscn") as PackedScene).instantiate())
	dummy.position = Vector3(3.0, 0.0, 0.0)
	_arena.add_child(dummy)
	var sensor: Array = _sensor(Vector3(7.0, 0.0, 0.0))
	await _ticks(2)
	NoiseSystem.emit_noise(NoiseEvent.FOOTSTEP_SPRINT, Vector3.ZERO, 12.0)
	assert_int(sensor[1][0].walls).is_equal(0)


func test_noise_is_announced_on_the_event_bus() -> void:
	var seen: Array[NoiseEvent] = []
	var on_noise: Callable = func(event: NoiseEvent) -> void: seen.append(event)
	EventBus.noise_emitted.connect(on_noise)
	NoiseSystem.emit_noise(NoiseEvent.DOOR, Vector3(1.0, 0.0, 2.0), 10.0)
	EventBus.noise_emitted.disconnect(on_noise)
	assert_int(seen.size()).is_equal(1)
	assert_vector(seen[0].position).is_equal(Vector3(1.0, 0.0, 2.0))


## Returns [sensor node, array of {type, distance, walls} for each noise heard].
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


func _wall(position: Vector3, size: Vector3 = Vector3(0.4, 3.0, 6.0)) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = position
	_arena.add_child(body)


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
