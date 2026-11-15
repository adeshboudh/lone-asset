extends GdUnitTestSuite


func test_head_hands_legs_and_vest_are_hidden_but_the_jacket_shows() -> void:
	for part: String in ["pol head", "pol helmet", "pol hand", "pol pants", "boot war1", "pol bproof"]:
		assert_bool(PlayerBodyRules.hidden_from_camera(part)).is_true()
	assert_bool(PlayerBodyRules.hidden_from_camera("pol jaket")).is_false()


func test_name_match_ignores_case() -> void:
	assert_bool(PlayerBodyRules.hidden_from_camera("Helmet_01")).is_true()


func test_hand_target_rises_when_aiming_and_drops_when_sprinting() -> void:
	var hold: Vector3 = Vector3(0.1, 1.3, -0.4)
	var ads: Vector3 = Vector3(-0.05, 0.1, 0.0)
	var sprint: Vector3 = Vector3(0.0, -0.2, 0.1)
	assert_float(PlayerBodyRules.hand_target(hold, ads, 1.0, sprint, 0.0, 0.0, 0.0).y).is_equal_approx(1.4, 0.0001)
	assert_float(PlayerBodyRules.hand_target(hold, ads, 0.0, sprint, 1.0, 0.0, 0.0).y).is_equal_approx(1.1, 0.0001)


func test_aiming_cancels_the_sprint_lowering() -> void:
	var hold: Vector3 = Vector3(0.1, 1.3, -0.4)
	var target: Vector3 = PlayerBodyRules.hand_target(hold, Vector3.ZERO, 1.0, Vector3(0.0, -0.2, 0.0), 1.0, 0.0, 0.0)
	assert_float(target.y).is_equal_approx(1.3, 0.0001)


func test_hand_target_follows_the_crouch_and_the_lean() -> void:
	var target: Vector3 = PlayerBodyRules.hand_target(Vector3(0.1, 1.3, -0.4), Vector3.ZERO, 0.0, Vector3.ZERO, 0.0, 0.65, 0.3)
	assert_vector(target).is_equal_approx(Vector3(0.4, 0.65, -0.4), Vector3(0.0001, 0.0001, 0.0001))


func test_bone_names_are_numbered_and_padded() -> void:
	var names: PackedStringArray = PlayerBodyRules.bone_names(14, 16)
	assert_array(names).is_equal(PackedStringArray(["Bone.014", "Bone.015", "Bone.016"]))


func test_arm_triangles_keep_triangles_mostly_on_the_chosen_bones() -> void:
	# Two triangles: vertices 0-2 are skinned to bone 1, vertices 3-5 to bone 0.
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5])
	var kept: PackedInt32Array = PlayerBodyRules.arm_triangles(arrays, {1: true})
	assert_array(kept).is_equal(PackedInt32Array([0, 1, 2]))


func test_arm_triangles_of_a_mesh_without_skinning_are_empty() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	assert_int(PlayerBodyRules.arm_triangles(arrays, {0: true}).size()).is_equal(0)


func test_hand_frame_is_a_proper_rotation() -> void:
	var frame: Basis = PlayerBodyRules.hand_frame(Vector3(0.3, -0.1, 1.0), Vector3(0.2, 0.9, 0.1))
	assert_float(frame.determinant()).is_equal_approx(1.0, 0.0001)
	assert_float(frame.x.dot(frame.z)).is_equal_approx(0.0, 0.0001)


func test_a_hand_that_has_not_moved_keeps_the_target_rest_basis() -> void:
	var rest: Basis = Basis(Vector3.UP, 0.4)
	var frame_rest: Basis = PlayerBodyRules.hand_frame(Vector3.FORWARD, Vector3.RIGHT)
	var wanted: Basis = PlayerBodyRules.frame_pose(rest, rest, frame_rest)
	var other_rest: Basis = Basis(Vector3.RIGHT, 0.7)
	var result: Basis = PlayerBodyRules.bone_basis_for_frame(wanted, frame_rest, other_rest)
	assert_float(result.x.distance_to(other_rest.x)).is_less(0.0001)
	assert_float(result.z.distance_to(other_rest.z)).is_less(0.0001)


func test_turning_the_source_bone_turns_the_target_bone_the_same_way() -> void:
	var rest: Basis = Basis()
	var frame_rest: Basis = PlayerBodyRules.hand_frame(Vector3.FORWARD, Vector3.RIGHT)
	var turn: Basis = Basis(Vector3.UP, 0.5)
	var wanted: Basis = PlayerBodyRules.frame_pose(turn * rest, rest, frame_rest)
	var result: Basis = PlayerBodyRules.bone_basis_for_frame(wanted, frame_rest, rest)
	assert_float(result.x.distance_to(turn.x)).is_less(0.0001)
