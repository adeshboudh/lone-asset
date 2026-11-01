extends GdUnitTestSuite
## Audio triggers: which sound plays on which bus for footsteps, weapon actions and impacts, and
## occlusion behind walls. (Headless Godot has no audio output, so this checks what is played.)

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

var _arena: Node3D
var _floor: StaticBody3D
var _player: Player
var _intent: InputIntent
var _played: Array[Dictionary] = []
var _recorder: Callable


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	_arena.add_child(LevelLighting.new())
	_arena.add_child(BallisticsSystem.new())
	_floor = _add_box(Vector3(80.0, 1.0, 80.0), Vector3(0.0, -0.5, 0.0))
	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	_intent = InputIntent.new()
	_player.set_scripted_intent(_intent)
	_played.clear()
	_recorder = func(id: StringName, bus: StringName) -> void: _played.append({"id": id, "bus": bus})
	Audio.sound_played.connect(_recorder)
	await _ticks(10)


func after_test() -> void:
	Audio.sound_played.disconnect(_recorder)


func test_footsteps_use_the_footsteps_bus_and_concrete_by_default() -> void:
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(90)
	assert_array(_ids("footstep_concrete")).is_not_empty()
	assert_str(_played[0]["bus"]).is_equal("Footsteps")


func test_footsteps_follow_the_surface() -> void:
	_floor.set_meta(&"surface", &"metal")
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(90)
	assert_array(_ids("footstep_metal")).is_not_empty()
	assert_array(_ids("footstep_concrete")).is_empty()


func test_no_footsteps_when_standing_still() -> void:
	await _ticks(90)
	assert_array(_played).is_empty()


func test_landing_sound_after_a_jump() -> void:
	_intent.jump = true
	await _ticks(1)
	_intent.jump = false
	await _ticks(90)
	assert_array(_ids("landing")).has_size(1)


func test_firing_plays_the_shot_on_the_weapons_bus() -> void:
	_fire_once()
	await _ticks(3)
	var shots: Array = _ids("rifle_shot_suppressed")
	assert_array(shots).has_size(1)
	assert_str(shots[0]["bus"]).is_equal("Weapons")


func test_reload_sound_depends_on_empty_magazine() -> void:
	_intent.reload = true
	_player.weapon.logic.magazine = 10
	await _ticks(2)
	_intent.reload = false
	assert_array(_ids("rifle_reload")).has_size(1)
	await _ticks(200)
	_played.clear()
	_player.weapon.logic.magazine = 0
	_intent.reload = true
	await _ticks(2)
	_intent.reload = false
	assert_array(_ids("rifle_reload_empty")).has_size(1)


func test_dry_fire_click_when_out_of_ammo() -> void:
	_player.weapon.logic.magazine = 0
	_player.weapon.logic.reserve = 0
	_fire_once()
	await _ticks(3)
	assert_array(_ids("rifle_dry")).has_size(1)
	assert_array(_ids("rifle_shot_suppressed")).is_empty()


func test_bullet_impact_makes_a_positional_sound() -> void:
	var wall: StaticBody3D = _add_box(Vector3(10.0, 10.0, 1.0), Vector3(0.0, 1.0, -8.0))
	assert_object(wall).is_not_null()
	_fire_once()
	await _ticks(30)
	assert_array(_ids("impact_world")).is_not_empty()


func test_sound_behind_a_wall_is_muffled_and_quieter() -> void:
	var camera: Camera3D = auto_free(Camera3D.new())
	_arena.add_child(camera)
	camera.global_position = Vector3(0.0, 1.6, 30.0)
	camera.current = true
	_add_box(Vector3(0.4, 4.0, 10.0), Vector3(10.0, 2.0, 30.0))
	await _ticks(2)
	_played.clear()
	var muffled: AudioStreamPlayer3D = Audio.play_3d(&"impact_world", Vector3(20.0, 0.0, 30.0))
	assert_array(_ids("impact_world_muffled")).has_size(1)
	assert_float(muffled.volume_db).is_equal(-6.0)
	_played.clear()
	var open: AudioStreamPlayer3D = Audio.play_3d(&"impact_world", Vector3(-20.0, 0.0, 30.0))
	assert_array(_ids("impact_world")).has_size(1)
	assert_float(open.volume_db).is_equal(0.0)


func test_unknown_sound_is_ignored() -> void:
	assert_object(Audio.play_2d(&"no_such_sound")).is_null()
	assert_object(Audio.play_3d(&"no_such_sound", Vector3.ZERO)).is_null()


func test_voice_pool_is_bounded() -> void:
	var voices: Dictionary = {}
	for i: int in 60:
		voices[Audio.play_3d(&"ui_click", Vector3(float(i), 0.0, 0.0))] = true
	assert_int(voices.size()).is_less_equal(Audio.MAX_VOICES_3D)


func test_wind_loop_is_a_looping_stream() -> void:
	var loop: AudioStreamPlayer = auto_free(Audio.make_loop(&"wind_loop"))
	assert_object(loop).is_not_null()
	assert_int((loop.stream as AudioStreamWAV).loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int((loop.stream as AudioStreamWAV).loop_end).is_greater(1000)
	assert_str(loop.bus).is_equal("Ambience")


func _ids(id: String) -> Array:
	return _played.filter(func(entry: Dictionary) -> bool: return entry["id"] == StringName(id))


func _fire_once() -> void:
	_intent.fire = true
	_intent.fire_pressed = true
	await get_tree().physics_frame
	_intent.fire_pressed = false
	_intent.fire = false


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
