extends GdUnitTestSuite
## Checkpoints on the real course: written when an objective asks for one, restored into a fresh level.
## Steps are physics ticks (60 per second).

const COURSE_SCENE: PackedScene = preload("res://game/levels/graybox/movement_course.tscn")

var _courses: Array[Node] = []


func before_test() -> void:
	Saves.delete_checkpoint()
	Saves.pending = {}


func after_test() -> void:
	for course: Node in _courses:
		if is_instance_valid(course):
			course.queue_free()
	_courses.clear()
	await get_tree().process_frame
	Saves.delete_checkpoint()
	Saves.pending = {}


func test_completing_an_objective_writes_a_checkpoint() -> void:
	var course: Node3D = await _course()
	assert_bool(Saves.has_checkpoint()).is_false()
	_teleport(course.get_node("Player"), Vector3(-22.5, 0.1, -24.5), 0.0)
	await _ticks(5)
	assert_bool(Saves.has_checkpoint()).is_true()
	var data: Dictionary = Saves.read_checkpoint()
	assert_str(data["mission_id"]).is_equal("m1_prototype")
	assert_str(data["objectives"]["obj_reach_compound"]).is_equal("completed")
	assert_str(data["objectives"]["obj_download_data"]).is_equal("active")
	assert_int(data["guards"].size()).is_equal(3)


func test_a_checkpoint_restores_the_player_guards_and_world() -> void:
	var first: Node3D = await _course()
	var player: Player = first.get_node("Player")
	# Change the world, then reach the objective that saves.
	first.get_node("Guards/GuardB").load_state({"position": [-14.0, 0.0, -16.0], "yaw": 0.0, "alive": false})
	(first.get_node("Compound/DoorSouth/Interactable") as Interactable).complete(player)
	player.health.health = 55.0
	player.weapon.logic.magazine = 7
	player.weapon.logic.reserve = 33
	Mission.guards_eliminated = 1
	_teleport(player, Vector3(-22.5, 0.1, -24.5), 1.0)
	await _ticks(5)
	assert_bool(Saves.has_checkpoint()).is_true()
	first.queue_free()
	_courses.erase(first)
	await _ticks(2)

	Saves.pending = Saves.read_checkpoint()
	var second: Node3D = await _course()
	var restored: Player = second.get_node("Player")
	assert_float(restored.global_position.x).is_equal_approx(-22.5, 0.05)
	assert_float(restored.global_position.z).is_equal_approx(-24.5, 0.05)
	assert_float(restored.rotation.y).is_equal_approx(1.0, 0.01)
	assert_float(restored.health.health).is_equal(55.0)
	assert_int(restored.weapon.logic.magazine).is_equal(7)
	assert_int(restored.weapon.logic.reserve).is_equal(33)
	assert_bool((second.get_node("Guards/GuardB") as Guard).is_dead).is_true()
	assert_bool((second.get_node("Guards/GuardA") as Guard).is_dead).is_false()
	assert_bool((second.get_node("Compound/DoorSouth") as Door).is_open).is_true()
	assert_bool((second.get_node("Compound/DoorEast") as Door).is_open).is_false()
	assert_int(Mission.state.status_of(&"obj_reach_compound")).is_equal(MissionState.Status.COMPLETED)
	assert_int(Mission.state.status_of(&"obj_download_data")).is_equal(MissionState.Status.ACTIVE)
	assert_int(Mission.guards_eliminated).is_equal(1)


func test_a_downloaded_terminal_stays_downloaded() -> void:
	var first: Node3D = await _course()
	Mission.state.on_trigger(&"compound_inner")
	(first.get_node("Compound/Terminal01/Interactable") as Interactable).complete(first.get_node("Player"))
	await _ticks(3)
	assert_bool(Saves.has_checkpoint()).is_true()
	first.queue_free()
	_courses.erase(first)
	await _ticks(2)
	Saves.pending = Saves.read_checkpoint()
	var second: Node3D = await _course()
	assert_bool((second.get_node("Compound/Terminal01") as Terminal).is_downloaded).is_true()


func test_a_crouching_player_is_restored_crouching() -> void:
	var first: Node3D = await _course()
	var player: Player = first.get_node("Player")
	var state: Dictionary = player.save_state()
	state["stance"] = "crouch"
	player.load_state(state)
	assert_bool(player.is_crouched).is_true()
	assert_float(player.save_state()["health"]).is_equal(100.0)


func test_importing_checks_the_save_before_storing_it() -> void:
	var bad: Array = Saves.import_text("{\"schema_version\": 99}")
	assert_bool(bad[0]).is_false()
	assert_bool(Saves.has_checkpoint()).is_false()
	var good: Dictionary = {"schema_version": 1, "mission_id": "m1_prototype", "objectives": {}, "player": {}, "guards": []}
	var ok: Array = Saves.import_text(SaveRules.to_text(good))
	assert_bool(ok[0]).is_true()
	assert_bool(Saves.has_checkpoint()).is_true()


func test_completing_the_mission_clears_the_checkpoint() -> void:
	var course: Node3D = await _course()
	_teleport(course.get_node("Player"), Vector3(-22.5, 0.1, -24.5), 0.0)
	await _ticks(5)
	assert_bool(Saves.has_checkpoint()).is_true()
	Mission.state.on_interaction(&"terminal_01")
	Mission.state.on_trigger(&"extraction_zone")
	assert_bool(Mission.state.was_successful).is_true()
	assert_bool(Saves.has_checkpoint()).is_false()


func _course() -> Node3D:
	var course: Node3D = COURSE_SCENE.instantiate()
	add_child(course)
	_courses.append(course)
	await _ticks(3)
	return course


func _teleport(player: Player, position: Vector3, yaw: float) -> void:
	player.global_position = position
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
