extends GdUnitTestSuite
## The visible body: whole person for shadows, no head, helmet or hands for the first-person camera.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

var _player: Player


func before_test() -> void:
	# A floor, so the player stands and the body is not posed as falling.
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
	_player.get_node("Body").update(_state(1.65, 0.0), pistol, 0.016)
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
	body.update(_state(1.65, 0.0), definition, 0.016)
	var standing_hip: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.007")).origin.y
	body.update(_state(1.0, 0.0), definition, 0.016)
	var crouched_hip: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.007")).origin.y
	assert_float(standing_hip - crouched_hip).is_greater(0.3)
	var ankle_standing: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("Bone.009")).origin
	var ankle_crouched: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.009")).origin
	assert_float(ankle_crouched.distance_to(ankle_standing)).is_less(0.05)


func test_walking_swings_the_feet_in_opposite_directions() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for i: int in 40:
		body.update(_state(1.65, 3.0), _player.weapon.definition, 0.016)
	var left: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.009")).origin.z
	var right: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.012")).origin.z
	assert_float(absf(left - right)).is_greater(0.2)


func test_standing_still_returns_the_feet_to_rest() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for i: int in 40:
		body.update(_state(1.65, 3.0), _player.weapon.definition, 0.016)
	for i: int in 60:
		body.update(_state(1.65, 0.0), _player.weapon.definition, 0.016)
	var left: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.009")).origin.z
	var right: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.012")).origin.z
	assert_float(absf(left - right)).is_less(0.03)


func _state(eye_height: float, speed: float) -> BodyPoseState:
	var state: BodyPoseState = BodyPoseState.new()
	state.eye_height = eye_height
	state.ground_speed = speed
	return state


func test_leaning_tips_the_head_toward_that_side() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var head_bone: int = skeleton.find_bone("Bone.005")
	var state: BodyPoseState = _state(1.65, 0.0)
	body.update(state, _player.weapon.definition, 0.016)
	var upright: float = (body.global_transform.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin)).x
	state.lean = 1.0
	body.update(state, _player.weapon.definition, 0.016)
	var leaned: float = (body.global_transform.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin)).x
	assert_float(leaned - upright).is_greater(0.15)


func test_airborne_feet_tuck_up() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var rest: float = skeleton.get_bone_global_rest(skeleton.find_bone("Bone.009")).origin.y
	var state: BodyPoseState = _state(1.65, 0.0)
	state.grounded = false
	for i: int in 30:
		body.update(state, _player.weapon.definition, 0.016)
	assert_float(skeleton.get_bone_global_pose(skeleton.find_bone("Bone.009")).origin.y - rest).is_greater(0.15)


func test_hard_landing_dips_the_pelvis_then_recovers() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var hip: int = skeleton.find_bone("Bone.007")
	var state: BodyPoseState = _state(1.65, 0.0)
	body.update(state, _player.weapon.definition, 0.016)
	var standing: float = skeleton.get_bone_global_pose(hip).origin.y
	state.grounded = false
	state.vertical_speed = -8.0
	body.update(state, _player.weapon.definition, 0.016)
	state.grounded = true
	for i: int in 3:
		body.update(state, _player.weapon.definition, 0.016)
	assert_float(standing - skeleton.get_bone_global_pose(hip).origin.y).is_greater(0.05)
	for i: int in 200:
		body.update(state, _player.weapon.definition, 0.016)
	assert_float(standing - skeleton.get_bone_global_pose(hip).origin.y).is_less(0.01)


func test_binoculars_bring_both_hands_to_the_face() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var state: BodyPoseState = _state(1.65, 0.0)
	state.binoculars_blend = 1.0
	body.update(state, _player.weapon.definition, 0.016)
	for pair: Array in [["Bone.038", 1.0], ["Bone.015", -1.0]]:
		var wrist: Vector3 = body.global_transform.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(pair[0])).origin)
		assert_float(wrist.distance_to(PlayerBodyRules.binocular_hand(pair[1], 1.65))).is_less(0.08)


func test_aiming_raises_the_hands() -> void:
	var body: PlayerBody = _player.get_node("Body")
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var state: BodyPoseState = _state(1.65, 0.0)
	body.update(state, _player.weapon.definition, 0.016)
	var hip: float = skeleton.get_bone_global_pose(skeleton.find_bone("Bone.038")).origin.y
	state.aim_blend = 1.0
	body.update(state, _player.weapon.definition, 0.016)
	assert_float(skeleton.get_bone_global_pose(skeleton.find_bone("Bone.038")).origin.y - hip).is_greater(0.05)
