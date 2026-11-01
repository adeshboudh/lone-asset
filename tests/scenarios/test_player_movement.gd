extends GdUnitTestSuite
## Player controller scenarios with scripted input in a small physics arena.
## Steps are counted in physics ticks (60 per second), so results do not depend on frame rate.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

var _arena: Node3D
var _player: Player
var _intent: InputIntent


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	_add_box(Vector3(40.0, 1.0, 40.0), Vector3(0.0, -0.5, 0.0))
	_arena.add_child(LevelLighting.new())
	_arena.add_child(BallisticsSystem.new())
	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	_intent = InputIntent.new()
	_player.set_scripted_intent(_intent)
	await _ticks(10)


func test_walks_at_walk_speed() -> void:
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(60)
	assert_float(_player.horizontal_speed).is_equal_approx(_player.settings.walk_speed, 0.05)
	assert_float(_player.global_position.z).is_less(-2.5)


func test_sprints_forward() -> void:
	_intent.move = Vector2(0.0, 1.0)
	_intent.sprint = true
	await _ticks(60)
	assert_bool(_player.is_sprinting).is_true()
	assert_float(_player.horizontal_speed).is_equal_approx(_player.settings.sprint_speed, 0.05)


func test_stops_without_input() -> void:
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(60)
	_intent.move = Vector2.ZERO
	await _ticks(30)
	assert_float(_player.horizontal_speed).is_less(0.01)


func test_crouch_and_stand() -> void:
	await _press_crouch()
	await _ticks(30)
	assert_int(_player.stance).is_equal(StanceComponent.Stance.CROUCH)
	await _press_crouch()
	await _ticks(30)
	assert_int(_player.stance).is_equal(StanceComponent.Stance.STAND)


func test_cannot_stand_under_low_ceiling() -> void:
	await _press_crouch()
	await _ticks(30)
	# 1.3 m ceiling over the crouched player.
	_add_box(Vector3(4.0, 0.3, 4.0), Vector3(0.0, 1.45, 0.0))
	await _ticks(2)
	await _press_crouch()
	await _ticks(30)
	assert_int(_player.stance).is_equal(StanceComponent.Stance.CROUCH)


func test_climbs_step_below_step_height() -> void:
	_add_box(Vector3(4.0, 0.25, 4.0), Vector3(0.0, 0.125, -3.0))
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(90)
	assert_float(_player.global_position.y).is_equal_approx(0.25, 0.05)
	assert_float(_player.global_position.z).is_less(-1.5)


func test_blocked_by_step_above_step_height() -> void:
	_add_box(Vector3(4.0, 0.5, 4.0), Vector3(0.0, 0.25, -3.0))
	_intent.move = Vector2(0.0, 1.0)
	await _ticks(90)
	assert_float(_player.global_position.y).is_less(0.05)
	assert_float(_player.global_position.z).is_greater(-1.0)


func test_jump_leaves_and_returns_to_floor() -> void:
	_intent.jump = true
	await _ticks(1)
	_intent.jump = false
	await _ticks(10)
	assert_bool(_player.is_on_floor()).is_false()
	assert_float(_player.global_position.y).is_greater(0.3)
	await _ticks(90)
	assert_bool(_player.is_on_floor()).is_true()


func test_lean_blocked_by_wall() -> void:
	_intent.lean = 1
	await _ticks(30)
	assert_float(_player.lean_amount).is_equal_approx(1.0, 0.01)
	_intent.lean = 0
	await _ticks(30)
	# Wall face 0.4 m to the right of the head (clear of the 0.35 m body radius).
	_add_box(Vector3(0.2, 3.0, 4.0), Vector3(0.5, 1.5, 0.0))
	await _ticks(2)
	_intent.lean = 1
	await _ticks(30)
	var expected: float = (0.4 - LeanComponent.HEAD_CLEARANCE) / _player.settings.lean_offset
	assert_float(_player.lean_amount).is_equal_approx(expected, 0.03)


func test_no_lean_while_sprinting() -> void:
	_intent.move = Vector2(0.0, 1.0)
	_intent.sprint = true
	_intent.lean = -1
	await _ticks(30)
	assert_float(_player.lean_amount).is_equal(0.0)


func _press_crouch() -> void:
	_intent.crouch_toggled = true
	await _ticks(1)
	_intent.crouch_toggled = false


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _add_box(size: Vector3, position: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = position
	_arena.add_child(body)
