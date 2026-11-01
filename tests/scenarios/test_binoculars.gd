extends GdUnitTestSuite
## Binoculars on the player: raising, zoom, tagging a guard (not through walls), tags expiring.
## Steps are physics ticks (60 per second).

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")
const GUARD_SCENE: PackedScene = preload("res://game/ai/guard/guard.tscn")

var _arena: Node3D
var _player: Player
var _guard: Guard
var _intent: InputIntent


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(200.0, 1.0, 200.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_arena.add_child(floor_body)

	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	# Faces -z by default; the guard stands 30 m ahead, facing away.
	_guard = GUARD_SCENE.instantiate()
	_guard.guard_id = &"tag_guard"
	_guard.position = Vector3(0.0, 0.0, -30.0)
	_guard.rotation.y = 0.0
	_arena.add_child(_guard)
	_intent = InputIntent.new()
	_player.set_scripted_intent(_intent)
	await _ticks(5)


func test_raising_zooms_the_camera_and_hides_the_weapon() -> void:
	var base_fov: float = _player.camera.fov
	_press_binoculars()
	await _ticks(40)
	assert_bool(_player.binoculars.is_active).is_true()
	assert_float(_player.camera.fov).is_less(base_fov * 0.4)
	assert_bool(_player.weapon.visible).is_false()
	_press_binoculars()
	await _ticks(40)
	assert_float(_player.camera.fov).is_equal_approx(base_fov, 0.5)
	assert_bool(_player.weapon.visible).is_true()


func test_the_wheel_switches_to_eight_times() -> void:
	_press_binoculars()
	await _ticks(5)
	var four: float = _player.camera.fov
	_intent.zoom_step = 1
	await _ticks(1)
	_intent.zoom_step = 0
	await _ticks(40)
	assert_float(_player.binoculars.zoom).is_equal(8.0)
	assert_float(_player.camera.fov).is_less(four)


func test_a_trigger_pull_does_not_fire_while_raised() -> void:
	_press_binoculars()
	await _ticks(5)
	var ammo: int = _player.weapon.logic.magazine
	_intent.fire = true
	_intent.fire_pressed = true
	await _ticks(20)
	_intent.fire = false
	_intent.fire_pressed = false
	assert_int(_player.weapon.logic.magazine).is_equal(ammo)


func test_holding_a_guard_in_the_centre_tags_it_after_half_a_second() -> void:
	_press_binoculars()
	await _ticks(10)
	assert_bool(_player.binoculars.is_tagged(_guard)).is_false()
	await _ticks(20)
	assert_float(_player.binoculars.tag_progress).is_greater(0.0)
	await _ticks(20)
	assert_bool(_player.binoculars.is_tagged(_guard)).is_true()


func test_a_guard_off_centre_is_not_tagged() -> void:
	_player.rotation.y = deg_to_rad(10.0)
	_press_binoculars()
	await _ticks(90)
	assert_bool(_player.binoculars.is_tagged(_guard)).is_false()


func test_a_wall_stops_tagging_but_a_tag_survives_one() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 4.0, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0.0, 2.0, -15.0)
	_arena.add_child(wall)
	await _ticks(2)
	_press_binoculars()
	await _ticks(90)
	assert_bool(_player.binoculars.is_tagged(_guard)).is_false()
	# Tagged earlier, the marker stays while the wall is in the way.
	_player.binoculars.tag(_guard)
	await _ticks(60)
	assert_bool(_player.binoculars.is_tagged(_guard)).is_true()


func test_tags_expire_after_sixty_seconds() -> void:
	_player.binoculars.tag(_guard)
	assert_bool(_player.binoculars.is_tagged(_guard)).is_true()
	assert_float(_player.binoculars.tag_time_left(_guard)).is_equal(60.0)
	# Advance the tag clock without playing a minute.
	_player.binoculars.physics_update(_player, InputIntent.new(), 59.0)
	assert_bool(_player.binoculars.is_tagged(_guard)).is_true()
	_player.binoculars.physics_update(_player, InputIntent.new(), 2.0)
	assert_bool(_player.binoculars.is_tagged(_guard)).is_false()


func test_a_dead_guard_loses_its_tag() -> void:
	_player.binoculars.tag(_guard)
	_guard.queue_free()
	await _ticks(3)
	assert_int(_player.binoculars.tag_count()).is_equal(0)


func _press_binoculars() -> void:
	_intent.binoculars_toggled = true
	await get_tree().physics_frame
	_intent.binoculars_toggled = false


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
