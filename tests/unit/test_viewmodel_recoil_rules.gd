extends GdUnitTestSuite


func _run(position: Vector3, velocity: Vector3, hz: float, damping: float, seconds: float) -> Array:
	var x: Vector3 = position
	var v: Vector3 = velocity
	var steps: int = int(seconds * 60.0)
	var lowest: float = 0.0
	for i: int in steps:
		var next: Array = ViewmodelRecoilRules.step(x, v, hz, damping, 1.0 / 60.0)
		x = next[0]
		v = next[1]
		lowest = minf(lowest, x.z)
	return [x, v, lowest]


func test_a_kick_springs_back_with_a_small_overshoot_and_settles() -> void:
	var kick: Vector3 = Vector3(0.0, 0.0, 1.0)
	var after: Array = _run(Vector3.ZERO, kick, 4.0, 0.45, 1.0)
	# Settled after a second.
	assert_float((after[0] as Vector3).length()).is_less(0.002)
	# It went past rest the other way (overshoot), but only a little.
	assert_float(after[2]).is_less(0.0)
	var peak: Array = _run(Vector3.ZERO, kick, 4.0, 0.45, 0.06)
	assert_float(-float(after[2])).is_less((peak[0] as Vector3).z * 0.4)


func test_the_spring_is_stable_with_a_long_frame() -> void:
	var x: Vector3 = Vector3(0.0, 0.0, 0.05)
	var v: Vector3 = Vector3.ZERO
	for i: int in 30:
		var next: Array = ViewmodelRecoilRules.step(x, v, 6.0, 0.45, 0.1)
		x = next[0]
		v = next[1]
	assert_float(x.length()).is_less(0.001)


func test_a_shot_kicks_back_and_up_and_less_when_aimed() -> void:
	var def: WeaponDefinition = WeaponDefinition.new()
	def.recoil_kick_back_m = 0.02
	def.recoil_kick_pitch_deg = 3.0
	def.recoil_kick_roll_deg = 2.0
	def.recoil_kick_yaw_deg = 1.0
	def.recoil_kick_ads_mult = 0.5
	var hip: Array = ViewmodelRecoilRules.shot_velocity(def, 0.0, 1.0, -1.0)
	# Back toward the camera (+z in the camera's frame) and muzzle up (+x pitch).
	assert_float((hip[0] as Vector3).z).is_greater(0.0)
	assert_float((hip[1] as Vector3).x).is_greater(0.0)
	# Random sideways parts follow the signed inputs.
	assert_float((hip[1] as Vector3).y).is_greater(0.0)
	assert_float((hip[1] as Vector3).z).is_less(0.0)
	var aimed: Array = ViewmodelRecoilRules.shot_velocity(def, 1.0, 1.0, -1.0)
	assert_float((aimed[0] as Vector3).z).is_equal_approx((hip[0] as Vector3).z * 0.5, 0.00001)


func test_no_kick_when_the_weapon_has_none() -> void:
	var def: WeaponDefinition = WeaponDefinition.new()
	var kick: Array = ViewmodelRecoilRules.shot_velocity(def, 0.0, 1.0, 1.0)
	assert_vector(kick[0]).is_equal(Vector3.ZERO)
	assert_vector(kick[1]).is_equal(Vector3.ZERO)


func test_rotating_about_the_pivot_keeps_the_pivot_still() -> void:
	var pivot: Vector3 = Vector3(0.1, -0.16, -0.05)
	var xf: Transform3D = ViewmodelRecoilRules.about_pivot(Vector3(5.0, 3.0, -4.0), pivot)
	assert_vector(xf * pivot).is_equal_approx(pivot, Vector3.ONE * 0.00001)
	# A point ahead of the pivot moves up when the muzzle pitches up.
	assert_float((xf * (pivot + Vector3(0.0, 0.0, -0.5))).y).is_greater(pivot.y)
