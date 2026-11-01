extends GdUnitTestSuite
## Settings apply to the audio buses, survive a save and load, and the new WP 11 sounds and stats.

const GUARD_SCENE: PackedScene = preload("res://game/ai/guard/guard.tscn")

var _saved: Dictionary = {}


func before_test() -> void:
	_saved = {"master": Settings.master_volume, "sfx": Settings.sfx_volume, "fov": Settings.fov_deg,
		"invert": Settings.invert_y, "sens": Settings.mouse_sensitivity_scale}


func after_test() -> void:
	Settings.master_volume = _saved["master"]
	Settings.sfx_volume = _saved["sfx"]
	Settings.fov_deg = _saved["fov"]
	Settings.invert_y = _saved["invert"]
	Settings.mouse_sensitivity_scale = _saved["sens"]
	Settings.commit()


func test_volume_changes_reach_the_buses() -> void:
	Settings.master_volume = 0.0
	Settings.sfx_volume = 0.5
	Settings.commit()
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))).is_equal(-80.0)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))).is_equal_approx(-6.02, 0.05)


func test_settings_survive_a_save_and_load() -> void:
	Settings.fov_deg = 90.0
	Settings.invert_y = true
	Settings.mouse_sensitivity_scale = 1.5
	Settings.commit()
	Settings.fov_deg = 75.0
	Settings.invert_y = false
	Settings.mouse_sensitivity_scale = 1.0
	Settings.load_from_disk()
	assert_float(Settings.fov_deg).is_equal(90.0)
	assert_bool(Settings.invert_y).is_true()
	assert_float(Settings.mouse_sensitivity_scale).is_equal(1.5)


func test_out_of_range_values_are_clamped_on_commit() -> void:
	Settings.fov_deg = 200.0
	Settings.commit()
	assert_float(Settings.fov_deg).is_equal(100.0)


func test_a_walking_guard_makes_footstep_sounds() -> void:
	var arena: Node3D = auto_free(Node3D.new())
	add_child(arena)
	var navmesh: NavigationMesh = NavigationMesh.new()
	navmesh.vertices = PackedVector3Array([Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(20, 0, 20), Vector3(-20, 0, 20)])
	navmesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.navigation_mesh = navmesh
	arena.add_child(region)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	arena.add_child(floor_body)
	var route: PatrolRoute = PatrolRoute.new()
	arena.add_child(route)
	for x: float in [-10.0, 10.0]:
		var point: PatrolPoint = PatrolPoint.new()
		point.position = Vector3(x, 0.0, 0.0)
		route.add_child(point)
	var steps: Array[int] = [0]
	var record: Callable = func(id: StringName, _bus: StringName) -> void:
		if id == &"footstep_concrete":
			steps[0] += 1
	Audio.sound_played.connect(record)
	var guard: Guard = GUARD_SCENE.instantiate()
	guard.guard_id = &"step_guard"
	guard.patrol_route = route
	guard.position = Vector3(-10.0, 0.0, 0.0)
	arena.add_child(guard)
	for i: int in 700:
		await get_tree().physics_frame
	Audio.sound_played.disconnect(record)
	assert_int(steps[0]).is_greater(3)


func test_the_summary_reports_detection_and_eliminations() -> void:
	Mission.start(load("res://data/missions/m1_prototype.tres"))
	Mission.guards_eliminated = 2
	assert_str(Mission.summary_text()).contains("Detected  no")
	assert_str(Mission.summary_text()).contains("Guards eliminated  2")
	Mission.state.on_combat_reached()
	assert_str(Mission.summary_text()).contains("Detected  yes")
