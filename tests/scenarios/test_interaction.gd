extends GdUnitTestSuite
## Doors, the terminal and the mission on the real course. Steps are physics ticks (60 per second).

const DOOR_SCENE: PackedScene = preload("res://game/interaction/door.tscn")
const GUARD_SCENE: PackedScene = preload("res://game/ai/guard/guard.tscn")
const COURSE_SCENE: PackedScene = preload("res://game/levels/graybox/movement_course.tscn")

var _arena: Node3D
var _course: Node3D


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)

	var navmesh: NavigationMesh = NavigationMesh.new()
	navmesh.vertices = PackedVector3Array([Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(20, 0, 20), Vector3(-20, 0, 20)])
	navmesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.navigation_mesh = navmesh
	_arena.add_child(region)

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(60.0, 1.0, 60.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_arena.add_child(floor_body)
	await _ticks(5)


func after_test() -> void:
	if is_instance_valid(_course):
		_course.queue_free()
		await get_tree().process_frame
	_course = null


func test_player_toggles_a_door() -> void:
	var door: Door = _door()
	var actor: Node3D = _player_stand_in()
	var interactable: Interactable = door.get_node("%Interactable")
	interactable.complete(actor)
	assert_bool(door.is_open).is_true()
	assert_str(interactable.prompt_text).is_equal("Close")
	await _ticks(60)
	assert_float(door.open_amount).is_equal(1.0)
	interactable.complete(actor)
	assert_bool(door.is_open).is_false()
	await _ticks(60)
	assert_float(door.open_amount).is_equal(0.0)


func test_a_closed_door_blocks_a_ray_and_an_open_door_does_not() -> void:
	var door: Door = _door()
	var from: Vector3 = Vector3(0.0, 1.0, 3.0)
	var to: Vector3 = Vector3(0.0, 1.0, -3.0)
	assert_bool(_ray_blocked(from, to)).is_true()
	(door.get_node("%Interactable") as Interactable).complete(_player_stand_in())
	await _ticks(60)
	assert_bool(_ray_blocked(from, to)).is_false()


func test_opening_a_door_makes_noise_for_the_player_only() -> void:
	var door: Door = _door()
	var heard: Array[NoiseEvent] = []
	var record: Callable = func(event: NoiseEvent) -> void: heard.append(event)
	EventBus.noise_emitted.connect(record)
	var interactable: Interactable = door.get_node("%Interactable")
	var guard_actor: Node3D = auto_free(Node3D.new())
	guard_actor.add_to_group(&"guards")
	_arena.add_child(guard_actor)
	interactable.complete(guard_actor)
	assert_int(heard.size()).is_equal(0)
	interactable.complete(_player_stand_in())
	EventBus.noise_emitted.disconnect(record)
	assert_int(heard.size()).is_equal(1)
	assert_str(heard[0].type).is_equal(NoiseEvent.DOOR)


func test_a_guard_opens_the_door_in_its_way() -> void:
	var door: Door = _door()
	var route: PatrolRoute = PatrolRoute.new()
	route.mode = PatrolSequence.Mode.LOOP
	_arena.add_child(route)
	for z: float in [-6.0, 6.0]:
		var point: PatrolPoint = PatrolPoint.new()
		point.wait_time = 0.1
		point.position = Vector3(0.0, 0.0, z)
		route.add_child(point)
	var guard: Guard = GUARD_SCENE.instantiate()
	guard.guard_id = &"door_guard"
	guard.patrol_route = route
	guard.position = Vector3(0.0, 0.0, -6.0)
	guard.profile = guard.profile.duplicate()
	guard.profile.patrol_speed = 4.0
	_arena.add_child(guard)
	var crossed: bool = false
	for i: int in 900:
		await get_tree().physics_frame
		if guard.global_position.z > 2.0:
			crossed = true
			break
	assert_bool(crossed).is_true()
	assert_bool(door.is_open).is_true()


func test_a_door_the_guard_opened_closes_again() -> void:
	var door: Door = _door()
	(door.get_node("%Interactable") as Interactable).complete(_guard_stand_in())
	assert_bool(door.is_open).is_true()
	await _ticks(int((Door.AI_CLOSE_DELAY_S + 1.5) * 60.0))
	assert_bool(door.is_open).is_false()


func test_mission_runs_end_to_end_on_the_course() -> void:
	var course: Node3D = COURSE_SCENE.instantiate()
	add_child(course)
	_course = course
	# The guards would fight the player; this test is about the objectives.
	course.get_node("Guards").queue_free()
	await _ticks(5)
	var player: Player = course.get_node("Player")
	var succeeded: Array[bool] = [false]
	Mission.mission_completed.connect(func() -> void: succeeded[0] = true)

	_teleport(player, Vector3(-22.5, 0.1, -24.5), 0.0)
	await _ticks(5)
	assert_int(Mission.state.status_of(&"obj_reach_compound")).is_equal(MissionState.Status.COMPLETED)

	# At the terminal, facing it. The download takes 4 s of holding.
	_teleport(player, Vector3(-27.6, 0.1, -25.0), PI * 0.5)
	await _ticks(5)
	var intent: InputIntent = InputIntent.new()
	intent.interact = true
	intent.interact_pressed = true
	player.set_scripted_intent(intent)
	await _ticks(2)
	intent.interact_pressed = false
	assert_float(player.interactor.hold_progress).is_greater(0.0)
	assert_int(Mission.state.status_of(&"obj_download_data")).is_equal(MissionState.Status.ACTIVE)
	await _ticks(260)
	player.set_scripted_intent(null)
	assert_int(Mission.state.status_of(&"obj_download_data")).is_equal(MissionState.Status.COMPLETED)

	_teleport(player, Vector3(25.0, 0.1, 25.0), 0.0)
	await _ticks(5)
	assert_bool(succeeded[0]).is_true()
	assert_bool(Mission.state.was_successful).is_true()


func test_letting_go_cancels_a_download() -> void:
	var course: Node3D = COURSE_SCENE.instantiate()
	add_child(course)
	_course = course
	course.get_node("Guards").queue_free()
	await _ticks(5)
	var player: Player = course.get_node("Player")
	Mission.state.on_trigger(&"compound_inner")
	_teleport(player, Vector3(-27.6, 0.1, -25.0), PI * 0.5)
	await _ticks(5)
	var intent: InputIntent = InputIntent.new()
	intent.interact = true
	intent.interact_pressed = true
	player.set_scripted_intent(intent)
	await _ticks(60)
	intent.interact = false
	await _ticks(2)
	assert_float(player.interactor.hold_progress).is_equal(0.0)
	player.set_scripted_intent(null)
	assert_int(Mission.state.status_of(&"obj_download_data")).is_equal(MissionState.Status.ACTIVE)


func _door() -> Door:
	var door: Door = DOOR_SCENE.instantiate()
	door.door_id = &"test_door"
	_arena.add_child(door)
	return door


## Something in the "player" group to use things with.
func _player_stand_in() -> Node3D:
	var actor: Node3D = auto_free(Node3D.new())
	actor.add_to_group(&"player")
	_arena.add_child(actor)
	return actor


func _guard_stand_in() -> Node3D:
	var actor: Node3D = auto_free(Node3D.new())
	actor.add_to_group(&"guards")
	_arena.add_child(actor)
	return actor


func _ray_blocked(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return not _arena.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _teleport(player: Player, position: Vector3, yaw: float) -> void:
	player.global_position = position
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
