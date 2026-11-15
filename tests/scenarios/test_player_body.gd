extends GdUnitTestSuite
## The visible body: whole person for shadows, no head, helmet or hands for the first-person camera.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

var _player: Player


func before_test() -> void:
	_player = auto_free(PLAYER_SCENE.instantiate())
	add_child(_player)
	await get_tree().physics_frame


func test_camera_does_not_render_the_hidden_layer() -> void:
	assert_int(_player.camera.cull_mask & PlayerBody.HIDDEN_LAYER).is_equal(0)


func test_head_helmet_and_hands_are_on_the_hidden_layer_and_still_cast_shadows() -> void:
	var hidden: int = 0
	for node: Node in _player.get_node("Body").find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		assert_int(mesh.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		if mesh.layers == PlayerBody.HIDDEN_LAYER:
			hidden += 1
			assert_bool(PlayerBodyRules.hidden_from_camera(mesh.name)).is_true()
	assert_int(hidden).is_equal(3)


func test_body_has_no_collision() -> void:
	assert_int(_player.get_node("Body").find_children("*", "CollisionObject3D", true, false).size()).is_equal(0)


func test_hands_reach_the_weapon_hold_points() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_hands_reach(_player.weapon.definition)
	var pistol: WeaponDefinition = load("res://data/weapons/pistol_suppressed.tres")
	_player.get_node("Body").update(1.65, pistol, 0.0, 1.0, true, 0.016)
	_assert_hands_reach(pistol)


func _assert_hands_reach(definition: WeaponDefinition) -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for pair: Array in [["Bone.038", definition.hold_right_hand], ["Bone.015", definition.hold_left_hand]]:
		var wrist: Vector3 = body.global_transform.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(pair[0])).origin)
		assert_float(wrist.distance_to(pair[1])).is_less(0.06)


func test_crouching_lowers_the_pelvis_and_bends_the_knees() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var definition: WeaponDefinition = _player.weapon.definition
	body.update(1.65, definition, 0.0, 1.0, true, 0.016)
	var standing_hip: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.007")).origin.y
	body.update(1.0, definition, 0.0, 1.0, true, 0.016)
	var crouched_hip: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.007")).origin.y
	assert_float(standing_hip - crouched_hip).is_greater(0.3)
	var ankle_standing: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("Bone.009")).origin
	var ankle_crouched: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.009")).origin
	assert_float(ankle_crouched.distance_to(ankle_standing)).is_less(0.05)


func test_walking_swings_the_feet_in_opposite_directions() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for i: int in 40:
		body.update(1.65, _player.weapon.definition, 3.0, 1.0, true, 0.016)
	var left: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.009")).origin.z
	var right: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.012")).origin.z
	assert_float(absf(left - right)).is_greater(0.2)


func test_standing_still_returns_the_feet_to_rest() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for i: int in 40:
		body.update(1.65, _player.weapon.definition, 3.0, 1.0, true, 0.016)
	for i: int in 60:
		body.update(1.65, _player.weapon.definition, 0.0, 1.0, true, 0.016)
	var left: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.009")).origin.z
	var right: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.012")).origin.z
	assert_float(absf(left - right)).is_less(0.03)
