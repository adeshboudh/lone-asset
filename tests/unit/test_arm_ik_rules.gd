extends GdUnitTestSuite


func test_elbow_keeps_both_bone_lengths_when_the_target_is_in_reach() -> void:
	var shoulder: Vector3 = Vector3(0.2, 1.4, 0.0)
	var target: Vector3 = Vector3(0.1, 1.2, -0.45)
	var elbow: Vector3 = ArmIkRules.elbow(shoulder, target, 0.26, 0.33, Vector3.DOWN)
	assert_float(shoulder.distance_to(elbow)).is_equal_approx(0.26, 0.001)
	assert_float(elbow.distance_to(target)).is_equal_approx(0.33, 0.001)


func test_elbow_bends_toward_the_pole() -> void:
	var shoulder: Vector3 = Vector3(0.2, 1.4, 0.0)
	var target: Vector3 = Vector3(0.2, 1.4, -0.45)
	var down: Vector3 = ArmIkRules.elbow(shoulder, target, 0.26, 0.33, Vector3.DOWN)
	var up: Vector3 = ArmIkRules.elbow(shoulder, target, 0.26, 0.33, Vector3.UP)
	assert_float(down.y).is_less(1.4)
	assert_float(up.y).is_greater(1.4)


func test_out_of_reach_target_gives_a_straight_arm() -> void:
	var shoulder: Vector3 = Vector3.ZERO
	var elbow: Vector3 = ArmIkRules.elbow(shoulder, Vector3(0.0, 0.0, -5.0), 0.26, 0.33, Vector3.DOWN)
	assert_float(elbow.z).is_equal_approx(-0.26, 0.01)


func test_aim_turns_one_direction_onto_another() -> void:
	var turned: Vector3 = ArmIkRules.aim(Vector3.RIGHT, Vector3.FORWARD) * Vector3.RIGHT
	assert_vector(turned).is_equal_approx(Vector3.FORWARD, Vector3(0.001, 0.001, 0.001))


func test_aim_handles_opposite_directions() -> void:
	var turned: Vector3 = ArmIkRules.aim(Vector3.RIGHT, Vector3.LEFT) * Vector3.RIGHT
	assert_vector(turned).is_equal_approx(Vector3.LEFT, Vector3(0.001, 0.001, 0.001))
