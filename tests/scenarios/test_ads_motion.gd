extends GdUnitTestSuite
## The aim move as the viewmodel and the camera see it: a damped spring (Weapon.visual_aim, AdsRules).

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

var _player: Player


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)
	_player = auto_free(PLAYER_SCENE.instantiate())
	add_child(_player)
	for i: int in 5:
		await get_tree().physics_frame


func _run(weapon: Weapon, seconds: float) -> Array[float]:
	var values: Array[float] = []
	for i: int in int(seconds * 60.0):
		weapon._process(1.0 / 60.0)
		values.append(weapon.visual_aim)
	return values


func test_raising_the_gun_rises_steadily_and_settles_on_the_sights() -> void:
	var weapon: Weapon = _player.weapon
	weapon._aim_target = 1.0
	var values: Array[float] = _run(weapon, 1.0)
	assert_float(values[0]).is_less(0.1)  # starts gently, not with a jump
	assert_float(values.max()).is_less(1.15)  # a small overshoot at most
	assert_float(values[values.size() - 1]).is_equal_approx(1.0, 0.005)
	var time_to_95: int = 0
	for i: int in values.size():
		if values[i] >= 0.95:
			time_to_95 = i
			break
	# 95 % of the way in about the weapon's ads_time
	assert_float(float(time_to_95) / 60.0).is_between(weapon.definition.ads_time * 0.4, weapon.definition.ads_time * 1.2)


func test_lowering_the_gun_returns_to_the_hip_without_bouncing() -> void:
	var weapon: Weapon = _player.weapon
	weapon._aim_target = 1.0
	_run(weapon, 1.0)
	weapon._aim_target = 0.0
	var values: Array[float] = _run(weapon, 1.0)
	assert_float(values.min()).is_greater_equal(-0.001)
	assert_float(values[values.size() - 1]).is_equal_approx(0.0, 0.005)


func test_letting_go_half_way_turns_round_without_a_snap() -> void:
	var weapon: Weapon = _player.weapon
	weapon._aim_target = 1.0
	var rising: Array[float] = _run(weapon, 0.1)
	var at_release: float = rising[rising.size() - 1]
	assert_float(at_release).is_between(0.15, 0.95)
	weapon._aim_target = 0.0
	var falling: Array[float] = _run(weapon, 1.0)
	var biggest_step: float = 0.0
	var previous: float = at_release
	for value: float in falling:
		biggest_step = maxf(biggest_step, absf(value - previous))
		previous = value
	# no frame jumps by more than the move's own peak speed
	assert_float(biggest_step).is_less(0.12)
	assert_float(falling.min()).is_greater_equal(-0.001)


func test_the_camera_zoom_follows_the_same_spring() -> void:
	var weapon: Weapon = _player.weapon
	weapon._aim_target = 1.0
	_run(weapon, 1.0)
	_player._process(1.0 / 60.0)
	assert_float(_player.camera.fov).is_equal_approx(weapon.definition.ads_fov, 0.5)
