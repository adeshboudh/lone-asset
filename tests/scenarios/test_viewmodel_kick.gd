extends GdUnitTestSuite
## The rifle's spring kick and hip turn on the real viewmodel (ViewmodelRecoilRules, Weapon).

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


func _muzzle_in_camera() -> Vector3:
	var muzzle: Node3D = _player.weapon.viewmodel.get_node("Muzzle") as Node3D
	return _player.camera.global_transform.affine_inverse() * muzzle.global_position


func test_a_shot_throws_the_gun_back_and_up_then_it_settles() -> void:
	var weapon: Weapon = _player.weapon
	weapon._process(0.0)
	var rest: Vector3 = _muzzle_in_camera()
	weapon.kick_viewmodel(0.0, 0.0)
	# Near the top of the swing (the spring swings back through rest after about a quarter second).
	for i: int in 3:
		weapon._process(1.0 / 60.0)
	var kicked: Vector3 = _muzzle_in_camera()
	# Back toward the eye and the muzzle up.
	assert_float(kicked.z).is_greater(rest.z + 0.005)
	assert_float(kicked.y).is_greater(rest.y + 0.005)
	for i: int in 60:
		weapon._process(1.0 / 60.0)
	assert_float(_muzzle_in_camera().distance_to(rest)).is_less(0.002)


func test_the_rifle_turns_in_at_the_hip() -> void:
	assert_float(_player.weapon.definition.viewmodel_hip_rotation_deg.y).is_greater(0.0)


## At the hip the barrel points where the bullets go: its line passes close to the crosshair point 20 m out.
func test_at_the_hip_the_barrel_points_at_the_crosshair() -> void:
	var weapon: Weapon = _player.weapon
	weapon._process(0.0)
	var cam: Transform3D = _player.camera.global_transform
	var muzzle: Vector3 = (weapon.viewmodel.get_node("Muzzle") as Node3D).global_position
	var barrel: Vector3 = -weapon.viewmodel.global_basis.z.normalized()
	var target: Vector3 = cam.origin - cam.basis.z.normalized() * 20.0
	var along: float = barrel.dot(target - muzzle)
	var closest: Vector3 = muzzle + barrel * along
	assert_float(closest.distance_to(target)).is_less(0.4)
