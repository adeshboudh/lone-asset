extends GdUnitTestSuite


func test_bone_frame_is_orthonormal_with_x_along_the_direction() -> void:
	var frame: Basis = FpsArmsRules.bone_frame(Vector3(0.0, 0.0, -2.0), Vector3(1.0, 0.3, 0.2))
	assert_vector(frame.x).is_equal_approx(Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.0001)
	assert_float(frame.x.dot(frame.z)).is_equal_approx(0.0, 0.0001)
	assert_float(frame.y.dot(frame.z)).is_equal_approx(0.0, 0.0001)
	assert_float(frame.determinant()).is_equal_approx(1.0, 0.0001)
	# The sideways axis keeps its side.
	assert_float(frame.z.x).is_greater(0.0)


func test_retarget_of_the_rest_frame_gives_the_rest() -> void:
	var rest: Basis = Basis(Vector3(0.3, 1.0, 0.2).normalized(), 0.7)
	var frame_rest: Basis = FpsArmsRules.bone_frame(rest * Vector3.UP, rest * Vector3.RIGHT)
	var out: Basis = FpsArmsRules.retarget(frame_rest, frame_rest, rest)
	for axis: int in 3:
		assert_vector(out[axis]).is_equal_approx(rest[axis], Vector3.ONE * 0.0001)


## The target bone ends up pointing where the source points, with its sideways axis where the source's is,
## whatever the target's own rest basis is; on a right hand and on a mirrored left hand alike.
func test_the_target_follows_the_source_on_both_hands() -> void:
	for mirror: float in [1.0, -1.0]:
		var direction: Vector3 = Vector3(0.0, 0.0, -1.0)
		var sideways: Vector3 = Vector3(mirror, 0.0, 0.0)
		var source_rest_frame: Basis = FpsArmsRules.bone_frame(direction, sideways)
		var curl: Basis = Basis(sideways, deg_to_rad(60.0))
		var source_pose_frame: Basis = curl * source_rest_frame
		# The target rig: different rest basis, its bone points along target_dir at rest.
		var target_rest: Basis = Basis(Vector3(0.2, 1.0, 0.1).normalized(), 0.9)
		var target_dir: Vector3 = target_rest * Vector3.UP
		var target_side: Vector3 = target_rest * Vector3(mirror, 0.0, 0.0)
		var target_rest_frame: Basis = FpsArmsRules.bone_frame(target_dir, target_side)
		var out: Basis = FpsArmsRules.retarget(source_pose_frame, target_rest_frame, target_rest)
		var posed_dir: Vector3 = out * Vector3.UP
		var posed_side: Vector3 = out * Vector3(mirror, 0.0, 0.0)
		assert_vector(posed_dir).is_equal_approx(curl * direction, Vector3.ONE * 0.0001)
		assert_vector(posed_side.normalized()).is_equal_approx(curl * sideways, Vector3.ONE * 0.0001)


func test_pack_bone_names() -> void:
	assert_str(FpsArmsRules.pack_bone("L_arm_01")).is_equal("LeftArm")
	assert_str(FpsArmsRules.pack_bone("R_elbow_024")).is_equal("RightForeArm")
	assert_str(FpsArmsRules.pack_bone("L_wrist_03")).is_equal("LeftHand")
	assert_str(FpsArmsRules.pack_bone("L_point2_09")).is_equal("LeftHandIndex2")
	assert_str(FpsArmsRules.pack_bone("R_thumb1_026")).is_equal("RightHandThumb1")
	assert_str(FpsArmsRules.pack_bone("L_middle2_00")).is_equal("LeftHandMiddle2")
	assert_str(FpsArmsRules.pack_bone("R_pink3_044")).is_equal("RightHandPinky3")
	assert_str(FpsArmsRules.pack_bone("L_ring1_015")).is_equal("LeftHandRing1")
	assert_str(FpsArmsRules.pack_bone("L_point4_011")).is_equal("")
	assert_str(FpsArmsRules.pack_bone("_rootJoint")).is_equal("")
