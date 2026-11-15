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
	_player.get_node("Body").update(1.65, pistol)
	_assert_hands_reach(pistol)


func _assert_hands_reach(definition: WeaponDefinition) -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for pair: Array in [["Bone.038", definition.hold_right_hand], ["Bone.015", definition.hold_left_hand]]:
		var wrist: Vector3 = body.global_transform.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(pair[0])).origin)
		assert_float(wrist.distance_to(pair[1])).is_less(0.06)
